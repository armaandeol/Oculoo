import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DateRangeOption { forever, thisMonth, custom }

class PillReminderPage extends StatefulWidget {
  @override
  _PillReminderPageState createState() => _PillReminderPageState();
}

class _PillReminderPageState extends State<PillReminderPage> {
  final _medicineController = TextEditingController();
  final _dosageController = TextEditingController();
  final _unitController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  int _dosageCount = 1;
  List<TextEditingController> _timeControllers = [TextEditingController()];
  String _frequency = 'Daily';
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

  void _onDateRangeOptionChanged(DateRangeOption? option) async {
    setState(() {
      _dateRangeOption = option!;
    });
    final today = DateTime.now();
    if (option == DateRangeOption.forever) {
      _startDateController.text = _formatDate(today);
      _endDateController.text = _formatDate(DateTime(today.year + 100, today.month, today.day));
    } else if (option == DateRangeOption.thisMonth) {
      final firstDay = DateTime(today.year, today.month, 1);
      final lastDay = DateTime(today.year, today.month + 1, 0);
      _startDateController.text = _formatDate(firstDay);
      _endDateController.text = _formatDate(lastDay);
    } else if (option == DateRangeOption.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: today, end: today.add(const Duration(days: 7))),
      );
      if (range != null) {
        setState(() {
          _startDateController.text = _formatDate(range.start);
          _endDateController.text = _formatDate(range.end);
        });
      } else {
        _dateRangeOption = DateRangeOption.forever;
        _onDateRangeOptionChanged(_dateRangeOption);
      }
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickTime(int index) async {
    final initialTime = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        _timeControllers[index].text = pickedTime.format(context);
      });
    }
  }

  Widget _buildWeeklySelector() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Wrap(
      spacing: 8.0,
      children: days.map((day) {
        return ChoiceChip(
          label: Text(day),
          selected: _selectedWeeklyDay == day,
          onSelected: (selected) {
            if (selected) setState(() => _selectedWeeklyDay = day);
          },
          selectedColor: Colors.blueAccent,
          labelStyle: TextStyle(
            color: _selectedWeeklyDay == day ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSelector() {
    final customDays = _selectedCustomDays.keys.toList();
    return Wrap(
      spacing: 8.0,
      children: customDays.map((dayLabel) {
        return FilterChip(
          label: Text(dayLabel),
          selected: _selectedCustomDays[dayLabel] ?? false,
          onSelected: (selected) {
            setState(() => _selectedCustomDays[dayLabel] = selected);
          },
          selectedColor: Colors.blueAccent,
          labelStyle: TextStyle(
            color: _selectedCustomDays[dayLabel]! ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  void _updateDosageTimes(String value) {
    final count = int.tryParse(value) ?? 1;
    if (count > 0) {
      setState(() {
        _dosageCount = count;
        if (_timeControllers.length < _dosageCount) {
          for (var i = _timeControllers.length; i < _dosageCount; i++) {
            _timeControllers.add(TextEditingController());
          }
        } else if (_timeControllers.length > _dosageCount) {
          _timeControllers.removeRange(_dosageCount, _timeControllers.length);
        }
      });
    }
  }

  Future<void> _showSummary() async {
    if (_medicineController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _unitController.text.isEmpty ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty ||
        _timeControllers.any((controller) => controller.text.isEmpty)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Incomplete Information"),
          content: const Text("Please fill out all fields before setting a reminder."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final daysSelected = _frequency == 'Weekly'
        ? _selectedWeeklyDay
        : _selectedCustomDays.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .join(", ");
    final timesSummary = _timeControllers.map((c) => c.text).join(", ");

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pill Reminder Summary"),
        content: Text(
          "Medicine: ${_medicineController.text}\n"
          "Total Dosage: ${_dosageController.text} ${_unitController.text}\n"
          "Times:\n - $timesSummary\n"
          "Start Date: ${_startDateController.text}\n"
          "End Date: ${_endDateController.text}\n"
          "Frequency: $_frequency\n"
          "Days: $daysSelected",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Error"),
              content: const Text("User is not authenticated. Please log in and try again."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }

        final String uid = user.uid;
        CollectionReference medicationsRef = FirebaseFirestore.instance
            .collection('patient')
            .doc(uid)
            .collection('Medications');

        QuerySnapshot medicationsSnapshot = await medicationsRef.get();
        int nextId = medicationsSnapshot.docs.length;

        final Map<String, dynamic> reminderData = {
          "medicine": _medicineController.text.trim(),
          "dosage": _dosageController.text.trim(),
          "unit": _unitController.text.trim(),
          "times": _timeControllers.map((c) => c.text.trim()).toList(),
          "start_date": _startDateController.text.trim(),
          "end_date": _endDateController.text.trim(),
          "frequency": _frequency,
          "days": daysSelected,
          "created_at": FieldValue.serverTimestamp(),
        };

        await medicationsRef.doc(nextId.toString()).set(reminderData);

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Pill reminder has been set successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: const Text("Failed to set reminder. Please try again."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        print("Error adding medication: $e");
      }
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    for (final tc in _timeControllers) {
      tc.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pill Reminder"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _medicineController,
                        decoration: InputDecoration(
                          labelText: "Medicine Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _dosageController,
                        decoration: InputDecoration(
                          labelText: "Total Dosage",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          labelText: "Units (mg, ml, etc.)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: "Number of Daily Dosages",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: _updateDosageTimes,
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: List.generate(_dosageCount, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0), // Vertical spacing
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _pickTime(index),
                                    child: AbsorbPointer(
                                      child: TextField(
                                        controller: _timeControllers[index],
                                        decoration: InputDecoration(
                                          labelText: "Time ${index + 1}",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16), // Horizontal spacing
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateController,
                              decoration: InputDecoration(
                                labelText: "Start Date",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _endDateController,
                              decoration: InputDecoration(
                                labelText: "End Date",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          RadioListTile<DateRangeOption>(
                            title: const Text("Forever"),
                            value: DateRangeOption.forever,
                            groupValue: _dateRangeOption,
                            onChanged: _onDateRangeOptionChanged,
                          ),
                          RadioListTile<DateRangeOption>(
                            title: const Text("This Month"),
                            value: DateRangeOption.thisMonth,
                            groupValue: _dateRangeOption,
                            onChanged: _onDateRangeOptionChanged,
                          ),
                          RadioListTile<DateRangeOption>(
                            title: const Text("Custom Range"),
                            value: DateRangeOption.custom,
                            groupValue: _dateRangeOption,
                            onChanged: _onDateRangeOptionChanged,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButton<String>(
                        value: _frequency,
                        items: ["Daily", "Weekly", "Custom"].map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _frequency = val!),
                      ),
                      if (_frequency == 'Weekly') _buildWeeklySelector(),
                      if (_frequency == 'Custom') _buildCustomSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showSummary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Set Reminder",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}