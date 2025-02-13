import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DateRangeOption { forever, thisMonth, custom }

class PillReminderPage extends StatefulWidget {
  @override
  _PillReminderPageState createState() => _PillReminderPageState();
}

class _PillReminderPageState extends State<PillReminderPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for basic info
  final TextEditingController _medicineController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  // Controllers for dates
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Time(s) controller list for daily dosages
  int _dosageCount = 1;
  List<TextEditingController> _timeControllers = [TextEditingController()];

  // Frequency & days
  String _frequency = 'Daily'; // Options: Daily, Weekly, Custom
  String _selectedWeeklyDay = 'Monday';
  Map<String, bool> _selectedCustomDays = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false
  };

  DateRangeOption _dateRangeOption = DateRangeOption.forever;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // By default, set startDate as today and endDate far in the future
    _startDateController.text = _formatDate(today);
    _endDateController.text = _formatDate(
        DateTime(today.year + 100, today.month, today.day)); // "Forever"
  }

  /// Formats DateTime as yyyy-MM-dd
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Opens a time picker and saves the selected time as a 24-hour string.
  Future<void> _pickTime(int index) async {
    final initialTime = TimeOfDay.now();
    final picked =
        await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _timeControllers[index].text = "$hour:$minute";
      });
    }
  }

  /// Opens a date range picker for custom date range selection.
  Future<void> _pickDateRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          DateTimeRange(start: today, end: today.add(Duration(days: 7))),
    );
    if (range != null) {
      setState(() {
        _startDateController.text = _formatDate(range.start);
        _endDateController.text = _formatDate(range.end);
      });
    }
  }

  /// Updates date range values based on the selected option.
  void _onDateRangeOptionChanged(DateRangeOption? option) async {
    if (option == null) return;
    setState(() {
      _dateRangeOption = option;
    });
    final today = DateTime.now();
    if (option == DateRangeOption.forever) {
      _startDateController.text = _formatDate(today);
      _endDateController.text =
          _formatDate(DateTime(today.year + 100, today.month, today.day));
    } else if (option == DateRangeOption.thisMonth) {
      final firstDay = DateTime(today.year, today.month, 1);
      final lastDay = DateTime(today.year, today.month + 1, 0);
      _startDateController.text = _formatDate(firstDay);
      _endDateController.text = _formatDate(lastDay);
    } else if (option == DateRangeOption.custom) {
      await _pickDateRange();
    }
  }

  /// Updates the number of daily dosages and ensures a matching list of time controllers.
  void _updateDosageCount(String value) {
    final count = int.tryParse(value) ?? 1;
    if (count > 0) {
      setState(() {
        _dosageCount = count;
        if (_timeControllers.length < _dosageCount) {
          for (var i = _timeControllers.length; i < _dosageCount; i++) {
            _timeControllers.add(TextEditingController());
          }
        } else if (_timeControllers.length > _dosageCount) {
          _timeControllers = _timeControllers.sublist(0, _dosageCount);
        }
      });
    }
  }

  /// Builds the frequency dropdown.
  Widget _buildFrequencySelector() {
    return DropdownButtonFormField<String>(
      value: _frequency,
      decoration: InputDecoration(
        labelText: "Frequency",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: ["Daily", "Weekly", "Custom"]
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _frequency = val!;
        });
      },
    );
  }

  /// When Weekly frequency is chosen, allows user to select a single day.
  Widget _buildWeeklySelector() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return Wrap(
      spacing: 8.0,
      children: days.map((day) {
        return ChoiceChip(
          label: Text(day),
          selected: _selectedWeeklyDay == day,
          onSelected: (selected) {
            if (selected) setState(() => _selectedWeeklyDay = day);
          },
        );
      }).toList(),
    );
  }

  /// When Custom frequency is chosen, allows user to select multiple days.
  Widget _buildCustomDaysSelector() {
    return Wrap(
      spacing: 8.0,
      children: _selectedCustomDays.keys.map((day) {
        return FilterChip(
          label: Text(day),
          selected: _selectedCustomDays[day] ?? false,
          onSelected: (selected) {
            setState(() {
              _selectedCustomDays[day] = selected;
            });
          },
        );
      }).toList(),
    );
  }

  /// Validates the form, builds the reminder data map, and saves it to Firestore.
  Future<void> _submitReminder() async {
    if (!_formKey.currentState!.validate()) return;

    // Prepare the days field based on frequency.
    dynamic daysSelected;
    if (_frequency == "Weekly") {
      daysSelected = [_selectedWeeklyDay];
    } else if (_frequency == "Custom") {
      daysSelected = _selectedCustomDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
    } else {
      daysSelected = "Daily";
    }

    // Build the reminder data map.
    Map<String, dynamic> reminderData = {
      "pillName": _medicineController.text.trim(),
      "dosage": _dosageController.text.trim(),
      "unit": _unitController.text.trim(),
      "times": _timeControllers.map((c) => c.text.trim()).toList(),
      "startDate": _startDateController.text.trim(),
      "endDate": _endDateController.text.trim(),
      "frequency": _frequency,
      "days": daysSelected,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("User not authenticated.")));
        return;
      }
      final uid = user.uid;
      CollectionReference remindersRef = FirebaseFirestore.instance
          .collection('patient')
          .doc(uid)
          .collection('Medications');
      await remindersRef.add(reminderData);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Pill reminder set successfully.")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving reminder: $e")));
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _timeControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pill Reminder"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Medicine Name
              TextFormField(
                controller: _medicineController,
                decoration: InputDecoration(
                  labelText: "Medicine Name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Enter medicine name"
                    : null,
              ),
              SizedBox(height: 16),
              // Dosage and Unit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: InputDecoration(
                        labelText: "Dosage",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter dosage"
                          : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: "Unit (mg, ml, etc.)",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? "Enter unit" : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Number of Daily Dosages
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Number of Daily Dosages",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                initialValue: "1",
                onChanged: _updateDosageCount,
              ),
              SizedBox(height: 16),
              // Time Pickers
              Column(
                children: List.generate(_dosageCount, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GestureDetector(
                      onTap: () => _pickTime(index),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _timeControllers[index],
                          decoration: InputDecoration(
                            labelText: "Time ${index + 1} (HH:mm)",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Select time"
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              // Date Range (Start & End)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      decoration: InputDecoration(
                        labelText: "Start Date",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDateController.text = _formatDate(picked);
                          });
                        }
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? "Select start date"
                          : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      decoration: InputDecoration(
                        labelText: "End Date",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDateController.text = _formatDate(picked);
                          });
                        }
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? "Select end date"
                          : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Date Range Options (Forever, This Month, Custom)
              Column(
                children: [
                  RadioListTile<DateRangeOption>(
                    title: Text("Forever"),
                    value: DateRangeOption.forever,
                    groupValue: _dateRangeOption,
                    onChanged: _onDateRangeOptionChanged,
                  ),
                  RadioListTile<DateRangeOption>(
                    title: Text("This Month"),
                    value: DateRangeOption.thisMonth,
                    groupValue: _dateRangeOption,
                    onChanged: _onDateRangeOptionChanged,
                  ),
                  RadioListTile<DateRangeOption>(
                    title: Text("Custom Range"),
                    value: DateRangeOption.custom,
                    groupValue: _dateRangeOption,
                    onChanged: _onDateRangeOptionChanged,
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Frequency and Days Selector
              _buildFrequencySelector(),
              SizedBox(height: 16),
              if (_frequency == "Weekly") _buildWeeklySelector(),
              if (_frequency == "Custom") _buildCustomDaysSelector(),
              SizedBox(height: 24),
              // Submit Button
              ElevatedButton(
                onPressed: _submitReminder,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text("Set Reminder", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
