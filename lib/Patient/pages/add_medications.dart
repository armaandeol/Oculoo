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

  int _dosageCount = 1;
  List<TextEditingController> _timeControllers = [TextEditingController()];
  String _frequency = 'Daily';
  String _selectedWeeklyDay = 'Mon';
  String _selectedUnit = 'mg';
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
  final List<String> _units = ['mg', 'tablet', 'mL', 'dose', 'drop'];
  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

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

  // ... [Keep existing time picker and date range handling logic] ...

  void _updateDosageCount(String value) {
    final count = int.tryParse(value) ?? 1;
    if (count > 0 && count <= 8) {
      // Dispose unused controllers
      if (count < _timeControllers.length) {
        for (int i = count; i < _timeControllers.length; i++) {
          _timeControllers[i].dispose();
        }
      }
      setState(() => _timeControllers = List.generate(
          count,
          (i) => i < _timeControllers.length
              ? _timeControllers[i]
              : TextEditingController())
        ..forEach((c) => c.text.isEmpty ? c.text = '00:00' : null));
    }
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
                validator: (v) => v!.trim().isEmpty ? "Required field" : null,
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
                        final amount = double.tryParse(v);
                        if (amount == null) return "Invalid number";
                        if (amount <= 0) return "Must be positive";
                        if (amount > 1000) return "Max 1000";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: "Unit*",
                      ),
                      items: _units
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      validator: (v) => v == null ? "Select unit" : null,
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: "1",
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Daily Doses*",
                    hintText: "How many times per day?"),
                validator: (v) {
                  final count = int.tryParse(v ?? '');
                  if (count == null || count < 1) return "Enter 1-8";
                  if (count > 8) return "Max 8 doses";
                  return null;
                },
                onChanged: _updateDosageCount,
              ),
              ...List.generate(
                  _timeControllers.length, (i) => _buildTimeField(i)),
            ],
          ),
        ),
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
          Row(
            children: [
              Expanded(
                  child: _buildDateField(_startDateController, "Start Date*")),
              if (_dateRangeOption == DateRangeOption.custom) ...[
                const SizedBox(width: 16),
                Expanded(
                    child: _buildDateField(_endDateController, "End Date*")),
              ],
            ],
          ),
          if (_dateRangeOption != DateRangeOption.forever)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                controller: _endDateController,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Auto-calculated end date",
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),
        ],
      );

  // ... [Keep other existing building methods] ...

  Map<String, dynamic> _buildReminderData() => {
        "medicine": _medicineController.text.trim(),
        "dose": "${_dosageController.text.trim()} $_selectedUnit",
        // ... [rest of the data structure] ...
      };

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
                  return "Use HH:MM format";
                }

                final now = TimeOfDay.now();
                final entered = v.split(':');
                final hour = int.parse(entered[0]);
                final minute = int.parse(entered[1]);

                if (hour > 23 || minute > 59) return "Invalid time";
                return null;
              },
            ),
          ),
        ),
      );
}
