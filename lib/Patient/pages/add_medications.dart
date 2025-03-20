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
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  List<TextEditingController> _timeControllers = [TextEditingController()];
  String _frequency = 'Daily';
  String _selectedWeeklyDay = 'Monday';
  String _selectedUnit = 'mg';
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

  final List<String> _units = ['mg', 'gram', 'ml', 'pills', 'others'];
  final _timeInputStyle = TextStyle(fontSize: 16, color: Colors.blueGrey[800]);

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

  void _addTimeField() {
    if (_timeControllers.length < 5) {
      setState(() => _timeControllers.add(TextEditingController()));
    }
  }

  void _removeTimeField(int index) {
    if (_timeControllers.length > 1) {
      setState(() => _timeControllers.removeAt(index));
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
          .add({
        "createdAt": FieldValue.serverTimestamp(),
        "days": _getSelectedDays(),
        "dosage": _dosageController.text.trim(),
        "endDate": _endDateController.text.trim(),
        "frequency": _frequency,
        "pillName": _medicineController.text.trim(),
        "startDate": _startDateController.text.trim(),
        "times": _timeControllers.map((c) => c.text.trim()).toList(),
        "unit": _selectedUnit,
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder saved successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent[400]!, Colors.lightBlue[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMedicineSection(),
                SizedBox(height: 20),
                _buildDosageSection(),
                SizedBox(height: 20),
                _buildScheduleSection(),
                SizedBox(height: 30),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineSection() => _SectionCard(
        title: "Medication Details",
        child: TextFormField(
          controller: _medicineController,
          style: _timeInputStyle,
          decoration: InputDecoration(
            labelText: "Medicine Name",
            prefixIcon: Icon(Icons.medication, color: Colors.blueAccent),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v!.isEmpty ? "Required field" : null,
        ),
      );

  Widget _buildDosageSection() => _SectionCard(
        title: "Dosage Information",
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _dosageController,
                    keyboardType: TextInputType.number,
                    style: _timeInputStyle,
                    decoration: InputDecoration(
                      labelText: "Dosage Amount",
                      prefixIcon:
                          Icon(Icons.exposure, color: Colors.blueAccent),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Required field";
                      return double.tryParse(v) == null
                          ? "Invalid number"
                          : null;
                    },
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: "Unit",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.scale, color: Colors.blueAccent),
                    ),
                    items: _units
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit, style: _timeInputStyle),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedUnit = value!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildTimeFieldsSection(),
          ],
        ),
      );

  Widget _buildTimeFieldsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Dosage Times",
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[800])),
          SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _timeControllers.length,
            separatorBuilder: (_, __) => SizedBox(height: 10),
            itemBuilder: (context, index) => Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(index),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _timeControllers[index],
                        style: _timeInputStyle,
                        decoration: InputDecoration(
                          labelText: "Time ${index + 1}",
                          prefixIcon:
                              Icon(Icons.access_time, color: Colors.blueAccent),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return "Select time";
                          return RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$')
                                  .hasMatch(v)
                              ? null
                              : "Invalid time";
                        },
                      ),
                    ),
                  ),
                ),
                if (index == _timeControllers.length - 1 &&
                    _timeControllers.length < 5)
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addTimeField,
                  ),
                if (_timeControllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeTimeField(index),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _buildScheduleSection() => _SectionCard(
        title: "Schedule Settings",
        child: Column(
          children: [
            _buildFrequencySelector(),
            SizedBox(height: 20),
            _buildDateRangeSelector(),
            SizedBox(height: 20),
            if (_frequency == "Weekly") _buildWeeklyDays(),
            if (_frequency == "Custom") _buildCustomDays(),
          ],
        ),
      );

  Widget _buildFrequencySelector() => DropdownButtonFormField<String>(
        value: _frequency,
        decoration: InputDecoration(
          labelText: "Frequency",
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.repeat, color: Colors.blueAccent),
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
          Text("Duration",
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[800])),
          Column(
            children: [
              RadioListTile<DateRangeOption>(
                title: Text("No End Date"),
                value: DateRangeOption.forever,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              RadioListTile<DateRangeOption>(
                title: Text("This Month Only"),
                value: DateRangeOption.thisMonth,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              RadioListTile<DateRangeOption>(
                title: Text("Custom Date Range"),
                value: DateRangeOption.custom,
                groupValue: _dateRangeOption,
                onChanged: _handleDateRangeSelection,
                dense: true,
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
          if (_dateRangeOption != DateRangeOption.forever)
            Row(
              children: [
                Expanded(
                    child: _buildDateField(_startDateController, "Start Date")),
                if (_dateRangeOption == DateRangeOption.custom) ...[
                  SizedBox(width: 16),
                  Expanded(
                      child: _buildDateField(_endDateController, "End Date")),
                ],
              ],
            ),
        ],
      );

  Widget _buildDateField(TextEditingController c, String label) =>
      TextFormField(
        controller: c,
        readOnly: true,
        style: _timeInputStyle,
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
          prefixIcon: Icon(Icons.calendar_today, color: Colors.blueAccent),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (v) => v!.isEmpty ? "Required field" : null,
      );

  Widget _buildWeeklyDays() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Day",
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[800])),
          SizedBox(height: 10),
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
                      selectedColor: Colors.blueAccent,
                      labelStyle: TextStyle(
                          color: _selectedWeeklyDay == day
                              ? Colors.white
                              : Colors.blueGrey),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _buildCustomDays() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Days",
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[800])),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _selectedCustomDays.keys
                .map((day) => FilterChip(
                      label: Text(day),
                      selected: _selectedCustomDays[day]!,
                      onSelected: (v) =>
                          setState(() => _selectedCustomDays[day] = v),
                      selectedColor: Colors.blueAccent,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                          color: _selectedCustomDays[day]!
                              ? Colors.white
                              : Colors.blueGrey),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _buildSubmitButton() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.blueAccent[400]!, Colors.lightBlue[300]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: _saveReminder,
          child: Text(
            "SAVE REMINDER",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white),
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                )),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
