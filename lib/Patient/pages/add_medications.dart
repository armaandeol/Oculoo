import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

enum DateRangeOption { forever, thisMonth, custom }

class PillReminderPage extends StatefulWidget {
  @override
  _PillReminderPageState createState() => _PillReminderPageState();
}

class _PillReminderPageState extends State<PillReminderPage> {
  final _formKey = GlobalKey<FormState>();
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
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false
  };
  DateRangeOption _dateRangeOption = DateRangeOption.forever;

  @override
  void initState() {
    super.initState();
    _initializeDates();
  }

  void _initializeDates() {
    final today = DateTime.now();
    _startDateController.text = _formatDate(today);
    _endDateController.text = _formatDate(DateTime(today.year + 100));
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _selectTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _timeControllers[index].text =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
    }
  }

  void _handleDateRangeSelection(DateRangeOption? option) async {
    if (option == null) return;

    setState(() => _dateRangeOption = option);
    final today = DateTime.now();

    switch (option) {
      case DateRangeOption.forever:
        _startDateController.text = _formatDate(today);
        _endDateController.text = _formatDate(DateTime(today.year + 100));
        break;
      case DateRangeOption.thisMonth:
        _startDateController.text =
            _formatDate(DateTime(today.year, today.month, 1));
        _endDateController.text =
            _formatDate(DateTime(today.year, today.month + 1, 0));
        break;
      case DateRangeOption.custom:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDateRange: DateTimeRange(
            start: today,
            end: today.add(const Duration(days: 7)),
          ),
        );
        if (range != null) {
          _startDateController.text = _formatDate(range.start);
          _endDateController.text = _formatDate(range.end);
        }
        break;
    }
  }

  void _updateDosageCount(String value) {
    final count = int.tryParse(value) ?? 1;
    if (count > 0 && count <= 8) {
      setState(() => _timeControllers = List.generate(
          count,
          (i) => i < _timeControllers.length
              ? _timeControllers[i]
              : TextEditingController())
        ..forEach((c) => c.text.isEmpty ? c.text = '00:00' : null));
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequency == "Custom" && !_selectedCustomDays.containsValue(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one day")));
      return;
    }

    final startDate = DateTime.parse(_startDateController.text);
    final endDate = DateTime.parse(_endDateController.text);
    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("End date cannot be before start date")));
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .collection('Medications')
          .add(_buildReminderData());

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder saved successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  Map<String, dynamic> _buildReminderData() => {
        "medicine": _medicineController.text.trim(),
        "dose":
            "${_dosageController.text.trim()} ${_unitController.text.trim()}",
        "times": _timeControllers.map((c) => c.text.trim()).toList(),
        "schedule": {
          "start": _startDateController.text.trim(),
          "end": _endDateController.text.trim(),
          "frequency": _frequency.toLowerCase(),
          "days": _getSelectedDays(),
        },
        "createdAt": FieldValue.serverTimestamp(),
      };

  dynamic _getSelectedDays() {
    if (_frequency == "Weekly") return [_selectedWeeklyDay];
    if (_frequency == "Custom")
      return _selectedCustomDays.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
    return null;
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    for (var c in _timeControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Medication Reminder"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMedicineSection(),
              const SizedBox(height: 24),
              _buildDosageSection(),
              const SizedBox(height: 24),
              _buildScheduleSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineSection() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Medication Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _medicineController,
                decoration: const InputDecoration(
                  labelText: "Medicine Name*",
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required field";
                  return null;
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildDosageSection() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dosage Information",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Amount*", hintText: "e.g., 500"),
                      validator: (v) {
                        if (v!.isEmpty) return "Required field";
                        if (double.tryParse(v) == null) return "Invalid number";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                          labelText: "Unit*", hintText: "e.g., mg, tablets"),
                      validator: (v) => v!.isEmpty ? "Required field" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                onChanged: _updateDosageCount,
                keyboardType: TextInputType.number,
                initialValue: "1",
                decoration: const InputDecoration(
                    labelText: "Daily Doses*",
                    hintText: "How many times per day?"),
                validator: (v) {
                  final count = int.tryParse(v ?? '');
                  if (count == null || count < 1) return "Enter 1-8";
                  return null;
                },
              ),
              ...List.generate(
                  _timeControllers.length, (i) => _buildTimeField(i)),
            ],
          ),
        ),
      );

  Widget _buildTimeField(int index) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GestureDetector(
          onTap: () => _selectTime(index),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _timeControllers[index],
              decoration: InputDecoration(
                labelText: "Dose ${index + 1} Time*",
                prefixIcon: const Icon(Icons.access_time),
              ),
              validator: (v) {
                if (v!.isEmpty) return "Select time";
                if (!RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').hasMatch(v)) {
                  return "Invalid time format";
                }
                return null;
              },
            ),
          ),
        ),
      );

  Widget _buildScheduleSection() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Schedule Settings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildFrequencySelector(),
              const SizedBox(height: 20),
              _buildDateRangeSelector(),
              if (_frequency == "Weekly") _buildWeeklyDays(),
              if (_frequency == "Custom") _buildCustomDays(),
            ],
          ),
        ),
      );

  Widget _buildFrequencySelector() => DropdownButtonFormField<String>(
        value: _frequency,
        decoration: const InputDecoration(
          labelText: "Frequency*",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.repeat),
        ),
        items: const [
          DropdownMenuItem(value: 'Daily', child: Text("Every Day")),
          DropdownMenuItem(value: 'Weekly', child: Text("Specific Day Weekly")),
          DropdownMenuItem(value: 'Custom', child: Text("Custom Days")),
        ],
        onChanged: (v) => setState(() => _frequency = v ?? 'Daily'),
      );

  Widget _buildDateRangeSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Duration*", style: TextStyle(fontSize: 16)),
          Column(
            children: [
              RadioListTile<DateRangeOption>(
                title: const Text("No End Date"),
                value: DateRangeOption.forever,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
              ),
              RadioListTile<DateRangeOption>(
                title: const Text("This Month Only"),
                value: DateRangeOption.thisMonth,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
              ),
              RadioListTile<DateRangeOption>(
                title: const Text("Custom Date Range"),
                value: DateRangeOption.custom,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
              ),
            ],
          ),
          if (_dateRangeOption != DateRangeOption.forever)
            Row(
              children: [
                Expanded(
                    child:
                        _buildDateField(_startDateController, "Start Date*")),
                if (_dateRangeOption == DateRangeOption.custom) ...[
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildDateField(_endDateController, "End Date*")),
                ],
              ],
            ),
        ],
      );

  Widget _buildDateField(TextEditingController c, String label) =>
      TextFormField(
        controller: c,
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) c.text = _formatDate(date);
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (v) => v!.isEmpty ? "Required field" : null,
      );

  Widget _buildWeeklyDays() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text("Select Day*", style: TextStyle(fontSize: 16)),
          Wrap(
            spacing: 8,
            children: [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ]
                .map((day) => ChoiceChip(
                      label: Text(day),
                      selected: _selectedWeeklyDay == day,
                      onSelected: (_) =>
                          setState(() => _selectedWeeklyDay = day),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _buildCustomDays() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text("Select Days*", style: TextStyle(fontSize: 16)),
          Wrap(
            spacing: 8,
            children: _selectedCustomDays.keys
                .map((day) => FilterChip(
                      label: Text(day),
                      selected: _selectedCustomDays[day]!,
                      onSelected: (v) =>
                          setState(() => _selectedCustomDays[day] = v),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _buildSubmitButton() => ElevatedButton.icon(
        onPressed: _saveReminder,
        icon: const Icon(Icons.notifications_active),
        label: const Text("SAVE REMINDER",
            style: TextStyle(fontSize: 16, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blueAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
