import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'item_detail_screen.dart';

class ItemScreen extends StatefulWidget {
  final String listId;
  final String listTitle;

  ItemScreen({required this.listId, required this.listTitle});

  @override
  _ItemScreenState createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController itemQtyController = TextEditingController();
  DateTime? selectedDueDate;

  void addItem(String name, String quantity, DateTime dueDate) {
    FirebaseFirestore.instance
        .collection('groceryLists')
        .doc(widget.listId)
        .collection('items')
        .add({
          'name': name,
          'quantity': quantity,
          'purchased': false,
          'createdAt': Timestamp.now(),
          'dueDate': Timestamp.fromDate(dueDate),
        });
  }

  void updateItem(String id, String name, String quantity, DateTime dueDate) {
    FirebaseFirestore.instance
        .collection('groceryLists')
        .doc(widget.listId)
        .collection('items')
        .doc(id)
        .update({
          'name': name,
          'quantity': quantity,
          'dueDate': Timestamp.fromDate(dueDate),
        });
  }

  void togglePurchased(DocumentSnapshot doc) {
    FirebaseFirestore.instance
        .collection('groceryLists')
        .doc(widget.listId)
        .collection('items')
        .doc(doc.id)
        .update({'purchased': !doc['purchased']});
  }

  void deleteItem(String id) {
    FirebaseFirestore.instance
        .collection('groceryLists')
        .doc(widget.listId)
        .collection('items')
        .doc(id)
        .delete();
  }

  void showAddOrEditDialog({DocumentSnapshot? existingDoc}) {
    final isEditing = existingDoc != null;

    if (isEditing) {
      itemNameController.text = existingDoc['name'];
      itemQtyController.text = existingDoc['quantity'];
      selectedDueDate = (existingDoc['dueDate'] as Timestamp).toDate();
    } else {
      itemNameController.clear();
      itemQtyController.clear();
      selectedDueDate = null;
    }

    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(isEditing ? "Edit Item" : "Add Item"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: itemNameController,
                          decoration: InputDecoration(labelText: 'Item Name'),
                        ),
                        TextField(
                          controller: itemQtyController,
                          decoration: InputDecoration(labelText: 'Quantity'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              selectedDueDate == null
                                  ? 'No Due Date'
                                  : 'Due: ${DateFormat.yMMMd().format(selectedDueDate!)}',
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.calendar_today),
                              onPressed: () async {
                                final now = DateTime.now();
                                final firstDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final initialDate =
                                    selectedDueDate ?? firstDate;

                                if (initialDate.isBefore(firstDate)) {
                                  selectedDueDate = firstDate;
                                }

                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDueDate ?? firstDate,
                                  firstDate: firstDate,
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  setState(() => selectedDueDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        final name = itemNameController.text.trim();
                        final qty = itemQtyController.text.trim();

                        if (name.isEmpty ||
                            qty.isEmpty ||
                            selectedDueDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'All fields including due date are required',
                              ),
                            ),
                          );
                          return;
                        }

                        if (isEditing) {
                          updateItem(
                            existingDoc!.id,
                            name,
                            qty,
                            selectedDueDate!,
                          );
                        } else {
                          addItem(name, qty, selectedDueDate!);
                        }

                        Navigator.pop(context);
                      },
                      child: Text(isEditing ? "Update" : "Add"),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.listTitle)),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('groceryLists')
                .doc(widget.listId)
                .collection('items')
                .orderBy('dueDate')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final items = snapshot.data!.docs;

          if (items.isEmpty) {
            return Center(child: Text("No items yet. Tap + to add."));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final dueDate = (doc['dueDate'] as Timestamp).toDate();
              final now = DateTime.now();
              final isOverdue = dueDate.isBefore(
                DateTime(now.year, now.month, now.day),
              );

              return ListTile(
                leading: Checkbox(
                  value: doc['purchased'],
                  onChanged: (_) => togglePurchased(doc),
                ),
                title: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(itemDoc: doc),
                      ),
                    );
                  },
                  onLongPress: () {
                    showAddOrEditDialog(existingDoc: doc);
                  },
                  child: Text(
                    doc['name'],
                    style: TextStyle(
                      decoration:
                          doc['purchased'] ? TextDecoration.lineThrough : null,
                      color: isOverdue ? Colors.red : null,
                    ),
                  ),
                ),
                subtitle: Text(
                  'Qty: ${doc['quantity']} • Due: ${DateFormat.yMMMd().format(dueDate)}',
                  style: TextStyle(color: isOverdue ? Colors.red : null),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOverdue)
                      IconButton(
                        icon: Icon(Icons.edit_calendar, color: Colors.blueGrey),
                        onPressed: () async {
                          final firstDate = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          ); // today
                          final currentDueDate = dueDate;

                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                currentDueDate.isBefore(firstDate)
                                    ? firstDate
                                    : currentDueDate,
                            firstDate: firstDate,
                            lastDate: DateTime(now.year + 5),
                          );

                          if (picked != null) {
                            FirebaseFirestore.instance
                                .collection('groceryLists')
                                .doc(widget.listId)
                                .collection('items')
                                .doc(doc.id)
                                .update({
                                  'dueDate': Timestamp.fromDate(picked),
                                });
                          }
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text('Delete Item'),
                                content: Text(
                                  'Are you sure you want to delete "${doc['name']}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      deleteItem(doc.id);
                                      Navigator.of(ctx).pop();
                                    },
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddOrEditDialog(),
        child: Icon(Icons.add),
        tooltip: 'Add New Item',
      ),
    );
  }
}
