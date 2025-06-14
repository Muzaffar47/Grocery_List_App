import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'item_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController listController = TextEditingController();

  void createList(BuildContext context, String title) {
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('List title cannot be empty')));
      return;
    }

    FirebaseFirestore.instance
        .collection('groceryLists')
        .add({'title': title, 'createdAt': Timestamp.now()})
        .then((_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('List created successfully')));
        });
  }

  Future<void> deleteList(BuildContext context, String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete List?'),
            content: Text('Are you sure you want to delete this list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete ?? false) {
      await FirebaseFirestore.instance
          .collection('groceryLists')
          .doc(id)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('List deleted')));
    }
  }

  void showAddListDialog(BuildContext context) {
    listController.clear();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("New Grocery List"),
            content: TextField(
              controller: listController,
              decoration: InputDecoration(
                hintText: 'List Title',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  createList(context, listController.text.trim());
                  Navigator.pop(context);
                },
                child: Text("Create"),
              ),
            ],
          ),
    );
  }

  void showEditListDialog(BuildContext context, String id, String oldTitle) {
    listController.text = oldTitle;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Edit List Title"),
            content: TextField(
              controller: listController,
              decoration: InputDecoration(
                hintText: 'New Title',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final newTitle = listController.text.trim();
                  if (newTitle.isNotEmpty) {
                    FirebaseFirestore.instance
                        .collection('groceryLists')
                        .doc(id)
                        .update({'title': newTitle});
                  }
                  Navigator.pop(context);
                },
                child: Text("Update"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    final icons = [
      Icons.shopping_cart,
      Icons.fastfood,
      Icons.local_grocery_store,
      Icons.kitchen,
      Icons.list_alt,
      Icons.local_dining,
      Icons.breakfast_dining,
      Icons.cake,
      Icons.ramen_dining,
      Icons.set_meal,
      Icons.eco,
      Icons.emoji_food_beverage,
      Icons.local_florist,
      Icons.local_drink,
      Icons.icecream,
      Icons.soup_kitchen,
      Icons.bakery_dining,
      Icons.local_pizza,
      Icons.outdoor_grill,
      Icons.food_bank,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Grocery Lists"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              themeProvider.toggleTheme(!isDark);
              setState(() {}); // Immediate rebuild
            },
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('groceryLists')
                .orderBy('createdAt')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final lists = snapshot.data!.docs;

          if (lists.isEmpty) {
            return Center(
              child: Text("No grocery lists. Tap + to create one."),
            );
          }

          return ListView.separated(
            itemCount: lists.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (context, index) {
              final doc = lists[index];
              final listId = doc.id;
              final title = doc['title'];

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('groceryLists')
                        .doc(listId)
                        .collection('items')
                        .snapshots(),
                builder: (context, itemSnapshot) {
                  final itemCount = itemSnapshot.data?.docs.length ?? 0;

                  return AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    },
                    child: ListTile(
                      key: ValueKey(doc.id),
                      leading: Icon(icons[index % icons.length]),
                      title: Text(title),
                      subtitle: Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed:
                                () =>
                                    showEditListDialog(context, listId, title),
                            tooltip: 'Edit list name',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteList(context, listId),
                            tooltip: 'Delete this list',
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ItemScreen(
                                  listId: listId,
                                  listTitle: title,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddListDialog(context),
        child: Icon(Icons.add),
        tooltip: 'Add New Grocery List',
      ),
    );
  }
}
