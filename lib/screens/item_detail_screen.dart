import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatefulWidget {
  final DocumentSnapshot itemDoc;

  const ItemDetailScreen({super.key, required this.itemDoc});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late bool purchased;
  DateTime? dueDate;

  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.itemDoc['name'] ?? '');
    quantityController = TextEditingController(
      text: widget.itemDoc['quantity'] ?? '',
    );
    purchased = widget.itemDoc['purchased'] ?? false;

    try {
      dueDate = (widget.itemDoc['dueDate'] as Timestamp).toDate();
    } catch (e) {
      dueDate = null;
    }
  }

  Future<void> pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        dueDate = picked;
      });
    }
  }

  Future<void> updateItem() async {
    final updatedName = nameController.text.trim();
    final updatedQty = quantityController.text.trim();

    if (updatedName.isEmpty || updatedQty.isEmpty || dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All fields including due date are required.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('groceryLists')
        .doc(widget.itemDoc.reference.parent.parent!.id)
        .collection('items')
        .doc(widget.itemDoc.id)
        .update({
          'name': updatedName,
          'quantity': updatedQty,
          'purchased': purchased,
          'dueDate': Timestamp.fromDate(dueDate!),
        });

    setState(() {
      isEditing = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Item updated successfully')));
  }

  Widget buildInfoRow(String label, Widget valueWidget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        valueWidget,
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item Details'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (isEditing) {
                updateItem();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            buildInfoRow(
              'Name:',
              isEditing
                  ? TextField(controller: nameController)
                  : Text(
                    nameController.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
            ),
            buildInfoRow(
              'Quantity:',
              isEditing
                  ? TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                  )
                  : Text(
                    quantityController.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
            ),
            buildInfoRow(
              'Due Date:',
              isEditing
                  ? Row(
                    children: [
                      Text(
                        dueDate != null
                            ? DateFormat.yMMMMd().format(dueDate!)
                            : 'Select date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: pickDueDate,
                      ),
                    ],
                  )
                  : Text(
                    dueDate != null
                        ? DateFormat.yMMMMd().format(dueDate!)
                        : 'No due date set',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
            ),
            Text('Purchased:', style: Theme.of(context).textTheme.titleMedium),
            isEditing
                ? SwitchListTile(
                  title: Text(purchased ? 'Yes' : 'No'),
                  value: purchased,
                  onChanged: (val) => setState(() => purchased = val),
                )
                : Row(
                  children: [
                    Icon(
                      purchased ? Icons.check_circle : Icons.cancel,
                      color: purchased ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Text(purchased ? 'Yes' : 'No'),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
