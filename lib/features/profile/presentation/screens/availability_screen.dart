import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({Key? key}) : super(key: key);

  @override
  _AvailabilityScreenState createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _unavailableDates = {};

  // Initially all dates are available (checked)
  bool _isDateAvailable(DateTime day) {
    return !_unavailableDates.contains(DateTime(day.year, day.month, day.day));
  }

  void _toggleDateAvailability(DateTime day) {
    setState(() {
      final normalizedDate = DateTime(day.year, day.month, day.day);
      if (_isDateAvailable(day)) {
        _unavailableDates.add(normalizedDate);
      } else {
        _unavailableDates.remove(normalizedDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Availability'),
          backgroundColor: Colors.grey[900],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Tap dates to mark as unavailable',
                style: TextStyle(color: Colors.grey[300]),
              ),
            ),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => _selectedDay == day,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _toggleDateAvailability(selectedDay);
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                weekendTextStyle: const TextStyle(color: Colors.red),
                outsideTextStyle: TextStyle(color: Colors.grey[600]),
                // Custom styling for available/unavailable dates
                defaultTextStyle: const TextStyle(color: Colors.white),
                selectedTextStyle: const TextStyle(color: Colors.black),
                // selectedDecoration: BoxDecoration(
                //   color: Colors.blue[300],
                //   shape: BoxShape.circle,
                // ),
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDateAvailable(date)
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: _isDateAvailable(date)
                            ? Colors.white
                            : Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Available',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 24),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Unavailable',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
