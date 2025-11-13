import 'dart:convert';
import 'package:flutter/material.dart';
import 'db/db_helper.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  List<Map<String, dynamic>> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    items = await DBHelper.getMeals();
    setState(() {});
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text("History")),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (c, i) {
          final row = items[i];
          final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp']);
          final listItems = jsonDecode(row['items']) as List;
          return ListTile(
            title: Text("${row['total_calories']} kcal • ${row['note']}"),
            subtitle: Text("${DateFormat.yMd().add_jm().format(ts)}"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("Meal details"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: listItems
                        .map(
                          (e) => Text(
                            "${e['name']} • ${e['qty_g']}g • ${e['calories']} kcal",
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
