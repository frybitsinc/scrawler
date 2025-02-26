import 'dart:convert';

import 'package:bnotes/desktop/pages/desktop_profile_screen.dart';
import 'package:bnotes/desktop/pages/desktop_settings_screen.dart';
import 'package:bnotes/desktop_web/desktop_note_toolbar.dart';
import 'package:bnotes/desktop_web/desktop_note_widget.dart';
import 'package:bnotes/helpers/constants.dart';
import 'package:bnotes/helpers/globals.dart' as globals;
import 'package:bnotes/helpers/utility.dart';
import 'package:bnotes/models/drawer_folder.dart';
import 'package:bnotes/models/label.dart';
import 'package:bnotes/widgets/rs_drawer_item.dart';
import 'package:bnotes/widgets/scrawl_color_dot.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notes.dart';
import '../providers/labels_api_provider.dart';
import '../providers/notes_api_provider.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  late SharedPreferences prefs;
  ScreenSize _screenSize = ScreenSize.large;
  bool isBusy = false;
  List<Notes> notesList = [];
  List<Label> labelsList = [];
  List<DrawerFolder> folderList = [];

  List<Map<String, dynamic>> menu = [];
  // String _selectedDrawerIndex = 'all_notes';
  // final int _selectedIndex = 0;
  NavigationRailLabelType labelType = NavigationRailLabelType.none;

  // _onDrawerItemSelect(String menuId) {
  //   setState(() => _selectedDrawerIndex = menuId);
  // }

  // _getDrawerItemWidget(String menuId) {
  //   switch (menuId) {
  //     case 'all_notes':
  //       return const DesktopNotesScreen();
  //     case 'all_tasks':
  //       return const DesktopTasksScreen();
  //     default:
  //       return const Text("Error");
  //   }
  // }

  Future<void> getLabels() async {
    Map<String, String> post = {
      'postdata': jsonEncode({
        'api_key': globals.apiKey,
        'uid': globals.user!.userId,
        'qry': '',
        'sort': 'label_name',
        'page_no': 0,
        'offset': 100
      })
    };
    LabelsApiProvider.fecthLabels(post).then((value) {
      setState(() {
        if (value.error.isEmpty) {
          labelsList = value.labels;
          folderList =
              labelsList.map((e) => DrawerFolder(e.labelName, false)).toList();
        }
      });
    });
  }

  Future<void> getNotes() async {
    Map<String, String> post = {
      'postdata': jsonEncode({
        'api_key': globals.apiKey,
        'uid': globals.user!.userId,
        'qry': '',
        'sort': 'note_title'
      })
    };
    setState(() {
      isBusy = true;
    });
    NotesApiProvider.fecthNotes(post).then((value) {
      if (value.error.isEmpty) {
        notesList = value.notes;
        isBusy = false;
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value.error),
          duration: const Duration(seconds: 2),
        ));
      }
    });
  }

  Future<void> saveNote() async {}

  void onNoteSelected(Notes note) {
    setState(() {
      globals.selectedNote = note;
    });
  }

  @override
  void initState() {
    super.initState();
    menu = kMenu;
    getLabels();
    getNotes();
  }

  @override
  Widget build(BuildContext context) {
    Widget drawer = SizedBox(
      width: 280,
      child: Drawer(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              RSDrawerItem(
                label: 'Search',
                icon: const Icon(Symbols.search),
                onTap: () {},
              ),
              RSDrawerItem(
                icon: const Icon(Symbols.add_circle),
                label: 'Add Note',
                onTap: () {},
              ),
              kVSpace,
              Expanded(
                child: isBusy
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(folderList.length, (index) {
                              final notes = notesList
                                  .where((el) => el.noteLabel
                                      .contains(folderList[index].title))
                                  .toList();
                              return ExpansionTile(
                                shape: RoundedRectangleBorder(
                                  side: BorderSide.none,
                                  borderRadius:
                                      BorderRadius.circular(kBorderRadius),
                                ),
                                leading: Icon(folderList[index].expanded
                                    ? Symbols.folder_open
                                    : Symbols.folder),
                                title: Text(
                                  folderList[index].title,
                                  style: TextStyle(
                                      fontWeight: folderList[index].expanded
                                          ? FontWeight.bold
                                          : FontWeight.normal),
                                ),
                                onExpansionChanged: (value) => setState(() {
                                  folderList[index].expanded = value;
                                }),
                                children: notes
                                    .map((note) => RSDrawerItem(
                                          indent: true,
                                          icon: const Icon(Symbols.description),
                                          label: note.noteTitle,
                                          trailing: ScrawlColorDot(
                                              colorCode: note.noteColor),
                                          onTap: () => onNoteSelected(note),
                                        ))
                                    .toList(),
                              );
                            }),
                            kVSpace,
                            ...notesList
                                .where((el) => el.noteLabel.isEmpty)
                                .toList()
                                .map((note) => RSDrawerItem(
                                      onTap: () => onNoteSelected(note),
                                      icon: const Icon(Symbols.description),
                                      label: note.noteTitle,
                                      trailing: ScrawlColorDot(
                                          colorCode: note.noteColor),
                                    )),
                          ],
                        ),
                      ),
              ),
              RSDrawerItem(
                icon: const Icon(Symbols.delete),
                label: 'Trash',
                onTap: () {},
              ),
              RSDrawerItem(
                icon: const Icon(Symbols.settings),
                label: 'Settings',
                onTap: () {},
              ),
              RSDrawerItem(
                icon: const Icon(Symbols.account_circle),
                label: 'Account',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    return _screenSize == ScreenSize.large
        ? Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                drawer,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (globals.selectedNote.noteId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey))),
                          child: Row(
                            children: [
                              const Icon(Symbols.description),
                              kHSpace,
                              Expanded(
                                child: Text(
                                  globals.selectedNote.noteTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DesktopNoteToolbar(globals.selectedNote),
                            ],
                          ),
                        ),
                      Expanded(
                          child: DesktopNoteWidget(
                        note: globals.selectedNote,
                        onSave: () {},
                      )),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            appBar: AppBar(
              title: globals.selectedNote.noteId.isNotEmpty
                  ? Text(globals.selectedNote.noteTitle)
                  : const Text(kAppName),
              actions: [
                if (globals.selectedNote.noteId.isNotEmpty)
                  DesktopNoteToolbar(globals.selectedNote),
              ],
            ),
            drawer: drawer,
            body: DesktopNoteWidget(
              note: globals.selectedNote,
              onSave: () {},
            ),
          );
  }

  void showProfile() {
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1000, maxHeight: 800),
                child: const DesktopProfileScreen()),
          );
        });
  }

  void showSettings() {
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1000, maxHeight: 800),
                child: const DesktopSettingsScreen()),
          );
        });
  }

  void signOut() async {
    prefs = await SharedPreferences.getInstance();
    prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
}
