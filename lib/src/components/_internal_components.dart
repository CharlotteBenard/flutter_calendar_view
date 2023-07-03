// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../calendar_event_data.dart';
import '../constants.dart';
import '../enumerations.dart';
import '../event_arrangers/event_arrangers.dart';
import '../extensions.dart';
import '../modals.dart';
import '../painters.dart';
import '../typedefs.dart';
import 'event_scroll_notifier.dart';

/// Widget to display tile line according to current time.
class LiveTimeIndicator extends StatefulWidget {
  /// Width of indicator
  final double width;

  /// Height of total display area indicator will be displayed
  /// within this height.
  final double height;

  /// Width of time line use to calculate offset of indicator.
  final double timeLineWidth;

  /// settings for time line. Defines color, extra offset,
  /// and height of indicator.
  final HourIndicatorSettings liveTimeIndicatorSettings;

  /// Defines height occupied by one minute.
  final double heightPerMinute;

  /// Widget to display tile line according to current time.
  const LiveTimeIndicator(
      {Key? key,
      required this.width,
      required this.height,
      required this.timeLineWidth,
      required this.liveTimeIndicatorSettings,
      required this.heightPerMinute})
      : super(key: key);

  @override
  _LiveTimeIndicatorState createState() => _LiveTimeIndicatorState();
}

class _LiveTimeIndicatorState extends State<LiveTimeIndicator> {
  late Timer _timer;
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();

    _currentDate = DateTime.now();
    _timer = Timer(Duration(seconds: 1), setTimer);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Creates an recursive call that runs every 1 seconds.
  /// This will rebuild TimeLineIndicator every second. This will allow us
  /// to indicate live time in Week and Day view.
  void setTimer() {
    if (mounted) {
      setState(() {
        _currentDate = DateTime.now();
        _timer = Timer(Duration(seconds: 1), setTimer);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: CurrentTimeLinePainter(
        color: widget.liveTimeIndicatorSettings.color,
        height: widget.liveTimeIndicatorSettings.height,
        offset: Offset(
          widget.timeLineWidth + widget.liveTimeIndicatorSettings.offset,
          _currentDate.getTotalMinutes * widget.heightPerMinute,
        ),
      ),
    );
  }
}

/// Time line to display time at left side of day or week view.
class TimeLine extends StatelessWidget {
  /// Width of timeline
  final double timeLineWidth;

  /// Height for one hour.
  final double hourHeight;

  /// Total height of timeline.
  final double height;

  /// Offset for time line
  final double timeLineOffset;

  /// This will display time string in timeline.
  final DateWidgetBuilder timeLineBuilder;

  /// Flag to display half hours.
  final bool showHalfHours;

  static DateTime get _date => DateTime.now();

  double get _halfHourHeight => hourHeight / 2;

  /// Time line to display time at left side of day or week view.
  const TimeLine({
    Key? key,
    required this.timeLineWidth,
    required this.hourHeight,
    required this.height,
    required this.timeLineOffset,
    required this.timeLineBuilder,
    this.showHalfHours = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: ValueKey(hourHeight),
      constraints: BoxConstraints(
        maxWidth: timeLineWidth,
        minWidth: timeLineWidth,
        maxHeight: height,
        minHeight: height,
      ),
      child: Stack(
        children: [
          for (int i = 1; i < Constants.hoursADay; i++)
            _timelinePositioned(
              topPosition: hourHeight * i - timeLineOffset,
              bottomPosition: height - (hourHeight * (i + 1)) + timeLineOffset,
              hour: i,
            ),
          if (showHalfHours)
            for (int i = 0; i < Constants.hoursADay; i++)
              _timelinePositioned(
                topPosition: hourHeight * i - timeLineOffset + _halfHourHeight,
                bottomPosition:
                    height - (hourHeight * (i + 1)) + timeLineOffset,
                hour: i,
                minutes: 30,
              ),
        ],
      ),
    );
  }

  Widget _timelinePositioned({
    required double topPosition,
    required double bottomPosition,
    required int hour,
    int minutes = 0,
  }) {
    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      bottom: bottomPosition,
      child: Container(
        height: hourHeight,
        width: timeLineWidth,
        child: timeLineBuilder.call(
          DateTime(
            _date.year,
            _date.month,
            _date.day,
            hour,
            minutes,
          ),
        ),
      ),
    );
  }
}

/// A widget that display event tiles in day/week view.
class EventGenerator<T extends Object?> extends StatelessWidget {
  /// Height of display area
  final double height;

  /// width of display area
  final double width;

  /// List of events to display.
  final List<CalendarEventData<T>> events;

  /// Defines height of single minute in day/week view page.
  final double heightPerMinute;

  /// Defines how to arrange events.
  final EventArranger<T> eventArranger;

  /// Defines how event tile will be displayed.
  final EventTileBuilder<T> eventTileBuilder;

  /// Defines date for which events will be displayed in given display area.
  final DateTime date;

  /// Called when user taps on event tile.
  final CellTapCallback<T>? onTileTap;

  final EventScrollConfiguration scrollNotifier;

  final MinuteSlotSize minuteSlotSize;

  final double hoursColumnWidth;

  /// A widget that display event tiles in day/week view.
  const EventGenerator({
    Key? key,
    required this.height,
    required this.width,
    required this.events,
    required this.heightPerMinute,
    required this.eventArranger,
    required this.eventTileBuilder,
    required this.date,
    required this.onTileTap,
    required this.scrollNotifier,
    required this.minuteSlotSize,
    required this.hoursColumnWidth,
  }) : super(key: key);

  /// Arrange events and returns list of [Widget] that displays event
  /// tile on display area. This method uses [eventArranger] to get position
  /// of events and [eventTileBuilder] to display events.
  List<Widget> _generateEvents(BuildContext context) {
    // final events = eventArranger.arrange(
    //   events: this.events,
    //   height: height,
    //   width: width,
    //   heightPerMinute: heightPerMinute,
    // );

    final eventsGrid = EventGrid();
    final Map<CalendarEventData, EventDrawProperties> eventsDrawProperties =
        HashMap();
    List<CalendarEventData> events = List.of(this.events)..sort();
    for (final CalendarEventData event in List.of(events)) {
      final drawProperties = EventDrawProperties(event)
        ..calculateTopAndHeight(minuteSlotSize, heightPerMinute);

      if (drawProperties.left == null || drawProperties.width == null) {
        eventsGrid.add(drawProperties);
      }

      eventsDrawProperties[event] = drawProperties;
    }

    if (eventsGrid.drawPropertiesList.isNotEmpty) {
      eventsGrid.processEvents(hoursColumnWidth, width);
    }

    return eventsDrawProperties.entries
        .map((e) => Positioned(
              top: e.value.top,
              left: e.value.left,
              height: e.value.height,
              width: e.value.width,
              child: GestureDetector(
                onTap: () =>
                    onTileTap?.call([e.key as CalendarEventData<T>], date),
                child: Builder(builder: (context) {
                  // if (scrollNotifier.shouldScroll &&
                  //     this.events[index]
                  //         .events
                  //         .any((element) => element == scrollNotifier.event)) {
                  //   _scrollToEvent(context);
                  // }
                  return eventTileBuilder(
                    date,
                    e.key as CalendarEventData<T>,
                    e.key.startTime!,
                    e.key.endTime!,
                  );
                }),
              ),
            ))
        .toList();

    // return List.generate(events.length, (index) {
    //   return Positioned(
    //     top: events[index].top,
    //     bottom: events[index].bottom,
    //     left: events[index].left,
    //     right: events[index].right,
    //     child: GestureDetector(
    //       onTap: () => onTileTap?.call(events[index].events, date),
    //       child: Builder(builder: (context) {
    //         if (scrollNotifier.shouldScroll &&
    //             events[index]
    //                 .events
    //                 .any((element) => element == scrollNotifier.event)) {
    //           _scrollToEvent(context);
    //         }
    //         return eventTileBuilder(
    //           date,
    //           events[index].events,
    //           Rect.fromLTWH(
    //               events[index].left,
    //               events[index].top,
    //               width - events[index].right - events[index].left,
    //               height - events[index].bottom - events[index].top),
    //           events[index].startDuration,
    //           events[index].endDuration,
    //         );
    //       }),
    //     ),
    //   );
    // });
  }

  void _scrollToEvent(BuildContext context) {
    final duration = scrollNotifier.duration ?? Duration.zero;
    final curve = scrollNotifier.curve ?? Curves.ease;

    scrollNotifier.resetScrollEvent();

    ambiguate(WidgetsBinding.instance)?.addPostFrameCallback((timeStamp) async {
      try {
        await Scrollable.ensureVisible(
          context,
          duration: duration,
          curve: curve,
          alignment: 0.5,
        );
      } finally {
        scrollNotifier.completeScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _generateEvents(context),
    );
  }
}

class EventDrawProperties {
  /// The top position.
  double? top;

  /// The event rectangle height.
  double? height;

  /// The left position.
  double? left;

  /// The event rectangle width.
  double? width;

  /// The start time.
  DateTime? start;

  /// The end time.
  DateTime? end;

  EventDrawProperties(CalendarEventData event) {
    start = event.startTime;
    end = event.endTime;
  }

  // Calculates the top and the height of the event rectangle.
  void calculateTopAndHeight(
      MinuteSlotSize minuteSlotSize, double heightPerMinute) {
    final startTime = HourMinute.fromDateTime(dateTime: start!);
    top = (startTime.hour + (startTime.minute / 60)) *
        (minuteSlotSize.minutes * heightPerMinute);
    final duration = HourMinute.fromDuration(duration: end!.difference(start!));
    height = (duration.hour + (duration.minute / 60)) *
        (minuteSlotSize.minutes * heightPerMinute);
  }

  /// Returns whether this draw properties overlaps another.
  bool collidesWith(EventDrawProperties other) {
    return end!.isAfter(other.start!) && start!.isBefore(other.end!);
  }
}

class EventGrid {
  /// Events draw properties added to the grid.
  List<EventDrawProperties> drawPropertiesList = [];

  /// Adds a flutter week view event draw properties.
  void add(EventDrawProperties drawProperties) =>
      drawPropertiesList.add(drawProperties);

  /// Processes all display properties added to the grid.
  void processEvents(double hoursColumnWidth, double eventsColumnWidth) {
    List<List<EventDrawProperties>> columns = [];
    DateTime? lastEventEnding;
    for (final drawProperties in drawPropertiesList) {
      if (lastEventEnding != null &&
          drawProperties.start!.isAfter(lastEventEnding)) {
        packEvents(columns, hoursColumnWidth, eventsColumnWidth);
        columns.clear();
        lastEventEnding = null;
      }

      var placed = false;
      for (final column in columns) {
        if (!column.last.collidesWith(drawProperties)) {
          column.add(drawProperties);
          placed = true;
          break;
        }
      }

      if (!placed) {
        columns.add([drawProperties]);
      }

      if (lastEventEnding == null ||
          drawProperties.end!.compareTo(lastEventEnding) > 0) {
        lastEventEnding = drawProperties.end;
      }
    }

    if (columns.isNotEmpty) {
      packEvents(columns, hoursColumnWidth, eventsColumnWidth);
    }
  }

  /// Sets the left and right positions for each event in the connected group.
  void packEvents(List<List<EventDrawProperties>> columns,
      double hoursColumnWidth, double eventsColumnWidth) {
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      final column = columns[columnIndex];
      for (final drawProperties in column) {
        drawProperties.left = hoursColumnWidth +
            (columnIndex / columns.length) * eventsColumnWidth;
        final colSpan = calculateColSpan(columns, drawProperties, columnIndex);
        drawProperties.width = (eventsColumnWidth * colSpan) / (columns.length);
      }
    }
  }

  /// Checks how many columns the event can expand into, without colliding with other events.
  int calculateColSpan(List<List<EventDrawProperties>> columns,
      EventDrawProperties drawProperties, int column) {
    var colSpan = 1;
    for (var columnIndex = column + 1;
        columnIndex < columns.length;
        columnIndex++) {
      final column = columns[columnIndex];
      for (final other in column) {
        if (drawProperties.collidesWith(other)) {
          return colSpan;
        }
      }
      colSpan++;
    }

    return colSpan;
  }
}

/// A widget that allow to long press on calendar.
class PressDetector extends StatelessWidget {
  /// Height of display area
  final double height;

  /// width of display area
  final double width;

  /// Defines height of single minute in day/week view page.
  final double heightPerMinute;

  /// Defines date for which events will be displayed in given display area.
  final DateTime date;

  /// Called when user long press on calendar.
  final DatePressCallback? onDateLongPress;

  /// Called when user taps on day view page.
  ///
  /// This callback will have a date parameter which
  /// will provide the time span on which user has tapped.
  ///
  /// Ex, User Taps on Date page with date 11/01/2022 and time span is 1PM to 2PM.
  /// then DateTime object will be  DateTime(2022,01,11,1,0)
  final DateTapCallback? onDateTap;

  /// Defines size of the slots that provides long press callback on area
  /// where events are not available.
  final MinuteSlotSize minuteSlotSize;

  /// A widget that display event tiles in day/week view.
  const PressDetector({
    Key? key,
    required this.height,
    required this.width,
    required this.heightPerMinute,
    required this.date,
    required this.onDateLongPress,
    required this.onDateTap,
    required this.minuteSlotSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final heightPerSlot = minuteSlotSize.minutes * heightPerMinute;
    final slots = (Constants.hoursADay * 60) ~/ minuteSlotSize.minutes;

    return Container(
      height: height,
      width: width,
      child: Stack(
        children: [
          for (int i = 0; i < slots; i++)
            Positioned(
              top: heightPerSlot * i,
              left: 0,
              right: 0,
              bottom: height - (heightPerSlot * (i + 1)),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => onDateTap?.call(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    0,
                    minuteSlotSize.minutes * i,
                  ),
                ),
                onLongPress: () => onDateLongPress?.call(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    0,
                    minuteSlotSize.minutes * i,
                  ),
                ),
                child: SizedBox(width: width, height: heightPerSlot),
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class HourMinute {
  /// "Zero" time.
  static const HourMinute zero = HourMinute._internal(hour: 0, minute: 0);

  /// "Min" time.
  static const HourMinute min = zero;

  /// "Max" time.
  static const HourMinute max = HourMinute._internal(hour: 24, minute: 0);

  /// The current hour.
  final int hour;

  /// The current minute.
  final int minute;

  /// Allows to internally create a new hour minute time instance.
  const HourMinute._internal({
    required this.hour,
    required this.minute,
  });

  /// Creates a new hour minute time instance.
  const HourMinute({
    int hour = 0,
    int minute = 0,
  }) : this._internal(
          hour: hour < 0 ? 0 : (hour > 23 ? 23 : hour),
          minute: minute < 0 ? 0 : (minute > 59 ? 59 : minute),
        );

  /// Creates a new hour minute time instance from a given date time object.
  HourMinute.fromDateTime({
    required DateTime dateTime,
  }) : this._internal(hour: dateTime.hour, minute: dateTime.minute);

  /// Creates a new hour minute time instance from a given date time object.
  factory HourMinute.fromDuration({
    required Duration duration,
  }) {
    var hour = 0;
    var minute = duration.inMinutes;
    while (minute >= 60) {
      hour += 1;
      minute -= 60;
    }
    return HourMinute._internal(hour: hour, minute: minute);
  }

  /// Creates a new hour minute time instance.
  HourMinute.now() : this.fromDateTime(dateTime: DateTime.now());

  /// Calculates the sum of this hour minute and another.
  HourMinute add(HourMinute other) {
    var hour = this.hour + other.hour;
    var minute = this.minute + other.minute;
    while (minute > 59) {
      hour++;
      minute -= 60;
    }
    return HourMinute._internal(hour: hour, minute: minute);
  }

  /// Calculates the difference between this hour minute and another.
  HourMinute subtract(HourMinute other) {
    var hour = this.hour - other.hour;
    if (hour < 0) {
      return HourMinute.zero;
    }
    var minute = this.minute - other.minute;
    while (minute < 0) {
      if (hour == 0) {
        return HourMinute.zero;
      }
      hour--;
      minute += 60;
    }
    return HourMinute._internal(hour: hour, minute: minute);
  }

  @override
  String toString() => jsonEncode({'hour': hour, 'minute': minute});

  @override
  bool operator ==(Object other) {
    if (other is! HourMinute) {
      return false;
    }
    return identical(this, other) ||
        (hour == other.hour && minute == other.minute);
  }

  bool operator <(Object other) {
    if (other is! HourMinute) {
      return false;
    }

    return _calculateDifference(other) < 0;
  }

  bool operator <=(Object other) {
    if (other is! HourMinute) {
      return false;
    }
    return _calculateDifference(other) <= 0;
  }

  bool operator >(Object other) {
    if (other is! HourMinute) {
      return false;
    }
    return _calculateDifference(other) > 0;
  }

  bool operator >=(Object other) {
    if (other is! HourMinute) {
      return false;
    }
    return _calculateDifference(other) >= 0;
  }

  /// Attaches this instant to a provided date.
  DateTime atDate(DateTime date) =>
      DateTime(date.year, date.month, date.day).add(asDuration);

  /// Converts this instance into a duration.
  Duration get asDuration => Duration(hours: hour, minutes: minute);

  @override
  int get hashCode => hour.hashCode + minute.hashCode;

  /// Returns the difference in minutes between this and another hour minute time instance.
  int _calculateDifference(HourMinute other) =>
      (hour * 60 - other.hour * 60) + (minute - other.minute);
}
