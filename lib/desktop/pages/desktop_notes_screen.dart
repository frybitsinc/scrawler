import 'dart:convert';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bnotes/helpers/adaptive.dart';
import 'package:bnotes/helpers/constants.dart';
import 'package:bnotes/helpers/language.dart';
import 'package:bnotes/helpers/note_color.dart';
import 'package:bnotes/helpers/string_values.dart';
import 'package:bnotes/helpers/utility.dart';
import 'package:bnotes/helpers/globals.dart' as globals;
import 'package:bnotes/models/menu_item.dart';
import 'package:bnotes/models/notes.dart';
import 'package:bnotes/models/sort_items.dart';
import 'package:bnotes/providers/notes_api_provider.dart';
import 'package:bnotes/widgets/color_palette_button.dart';
import 'package:bnotes/widgets/scrawl_alert_dialog.dart';
import 'package:bnotes/widgets/scrawl_empty.dart';
import 'package:bnotes/widgets/scrawl_note_date_widget.dart';
import 'package:bnotes/widgets/scrawl_note_list_item.dart';
import 'package:bnotes/widgets/scrawl_snackbar.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class DesktopNotesScreen extends StatefulWidget {
  const DesktopNotesScreen({Key? key}) : super(key: key);

  @override
  State<DesktopNotesScreen> createState() => _DesktopNotesScreenState();
}

class _DesktopNotesScreenState extends State<DesktopNotesScreen> {
  List<Notes> notesList = [];
  List<Notes> filteredNotes = [];
  NoteSort currentSort = NoteSort.title;
  bool isNewNote = false;
  final int _pageNr = 0;
  bool isBusy = false;
  FocusNode focusNode = FocusNode();
  int wordCount = 0;
  bool isDesktop = false;
  int selectedIndex = 0;
  bool isSelected = false;
  bool darkModeOn = false;
  Offset _tapPosition = Offset.zero;
  List<MenuItem> contextMenuItems = [
    MenuItem('edit', Language.get('edit'), ''),
    MenuItem('delete', Language.get('delete'), ''),
    MenuItem('color', Language.get('color'), ''),
    MenuItem('tags', Language.get('tag'), '')
  ];
  List<SortItem> sortItems = [
    SortItem(NoteSort.title, 'A-Z'),
    SortItem(NoteSort.titleDesc, 'Z-A'),
    SortItem(NoteSort.newest, Language.get('latest')),
    SortItem(NoteSort.oldest, Language.get('oldest'))
  ];

  TextEditingController noteTitleController = TextEditingController();
  TextEditingController noteTextController = TextEditingController();
  String currentNoteId = "";

  void getNotes() async {
    Map<String, String> post = {
      'postdata': jsonEncode({
        'api_key': globals.apiKey,
        'uid': globals.user!.userId,
        'qry': '',
        'sort': 'note_title',
        'page_no': _pageNr,
        'offset': 30
      })
    };
    setState(() {
      isBusy = true;
    });
    NotesApiProvider.fecthNotes(post).then((value) {
      if (value.error.isEmpty) {
        notesList = value.notes;
        filteredNotes = notesList;
        isBusy = false;
        setState(() {});
        sortList(currentSort);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value.error),
          duration: const Duration(seconds: 2),
        ));
      }
    });
  }

  void sortList(NoteSort sort) {
    switch (sort) {
      case NoteSort.title:
        filteredNotes
            .sort((Notes a, Notes b) => a.noteTitle.compareTo(b.noteTitle));
        break;
      case NoteSort.titleDesc:
        filteredNotes
            .sort((Notes a, Notes b) => b.noteTitle.compareTo(a.noteTitle));
        break;
      case NoteSort.newest:
        filteredNotes
            .sort((Notes a, Notes b) => b.noteDate.compareTo(a.noteDate));
        break;
      case NoteSort.oldest:
        filteredNotes
            .sort((Notes a, Notes b) => a.noteDate.compareTo(b.noteDate));
        break;
      default:
        break;
    }
    currentSort = sort;
    setState(() {});
  }

  void onSearch(String phrase) {
    setState(() {
      filteredNotes = notesList
          .where((element) =>
              element.noteTitle.toLowerCase().contains(phrase.toLowerCase()) ||
              element.noteText.toLowerCase().contains(phrase.toLowerCase()))
          .toList();
    });
  }

  void saveNotes() async {
    var uuid = const Uuid();
    var newId = uuid.v1();
    late Notes currentNote;
    if (isNewNote) {
      currentNote = Notes(newId, Utility.getDateString(),
          noteTitleController.text, noteTextController.text, '', false, 0, '');
      filteredNotes.add(currentNote);
    } else {
      int editIndex = filteredNotes
          .indexWhere((element) => element.noteId == currentNoteId);
      filteredNotes[editIndex].noteTitle = noteTitleController.text;
      filteredNotes[editIndex].noteText = noteTextController.text;
      currentNote = filteredNotes[editIndex];
    }
    notesList = filteredNotes;
    setState(() {});
    sortList(currentSort);
    syncNotes(currentNote, newId);
  }

  void syncNotes(Notes note, String newId) async {
    Map<String, String> post = {
      'postdata': jsonEncode({
        'new': isNewNote,
        'api_key': globals.apiKey,
        'note_id': isNewNote ? newId : currentNoteId,
        'note_user_id': globals.user!.userId,
        'note_date': Utility.getDateString(),
        'note_title': note.noteTitle,
        'note_text': note.noteText,
        'note_label': note.noteLabel,
        'note_archived': note.noteArchived,
        'note_color': note.noteColor,
        'note_image': '',
        'note_audio_file': ''
      })
    };
    NotesApiProvider.updateNotes(post).then((value) {
      if (value['status']) {
        ScaffoldMessenger.of(context).showSnackBar(
            ScrawlSnackBar.show(context, Language.get('changes_saved')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value['error']),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void deleteNotes(String noteId) async {
    filteredNotes.removeWhere((element) => element.noteId == noteId);
    if (selectedIndex > 0) {
      selectedIndex--;
    } else {
      selectedIndex = 0;
      isSelected = false;
    }
    notesList = filteredNotes;
    setState(() {});
    Map<String, String> post = {
      'postdata': jsonEncode({
        'api_key': globals.apiKey,
        'note_id': noteId,
      })
    };
    NotesApiProvider.deleteNotes(post).then((value) {
      if (value['status']) {
        selectedIndex = 0;
        isSelected = false;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value['error']),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  List<PopupMenuItem<NoteSort>> getSortItems() {
    return sortItems
        .map<PopupMenuItem<NoteSort>>((item) => PopupMenuItem(
            value: item.sortBy,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.caption,
                  ),
                ),
                if (item.sortBy == currentSort)
                  const Icon(
                    BootstrapIcons.check,
                    size: 16.0,
                  )
              ],
            )))
        .toList();
  }

  void getAllLabels() async {
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
  }

  @override
  void initState() {
    getNotes();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    isDesktop = isDisplayDesktop(context);
    var brightness = MediaQuery.of(context).platformBrightness;
    darkModeOn = (globals.themeMode == ThemeMode.dark ||
        (globals.themeMode == ThemeMode.system &&
            brightness == Brightness.dark));

    AppBar appBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(Language.get('notes'),
          style: const TextStyle(color: Colors.black)),
      actions: [
        PopupMenuButton<NoteSort>(
          itemBuilder: (_) => getSortItems(),
          onSelected: (value) => sortList(value),
          icon: const Icon(Icons.sort_by_alpha_outlined),
          tooltip: Language.get('sort'),
        ),
      ],
    );

    Widget readerHead = Container(
      alignment: Alignment.center,
      height: 56,
      decoration: const BoxDecoration(
        color: kLightPrimary,
        border: Border(
          bottom: BorderSide(color: kLightStroke, width: 2),
        ),
      ),
      child: Text(
          isSelected && filteredNotes[selectedIndex].noteTitle.isNotEmpty
              ? filteredNotes[selectedIndex].noteTitle
              : '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );

    return Row(
      children: [
        SizedBox(
          width: 350,
          child: Scaffold(
            backgroundColor: kLightSecondary,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: UniversalPlatform.isWeb
                  ? appBar
                  : MoveWindow(
                      child: appBar,
                    ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: kLabels['search'],
                            prefixIcon: const Icon(
                              BootstrapIcons.search,
                            ),
                          ),
                          onChanged: (value) => onSearch(value),
                        ),
                      ),
                      kHSpace,
                      InkWell(
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kLightPrimary,
                            border: Border.all(color: kLightStroke, width: 2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.all(7),
                          child: const Icon(BootstrapIcons.plus),
                        ),
                        onTap: () {
                          assignFields(Notes.empty());
                          showEditDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isBusy
                      ? const Center(
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : (filteredNotes.isNotEmpty
                          ? ListView.builder(
                              padding: kGlobalOuterPadding,
                              itemCount: filteredNotes.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onSecondaryTapDown: (details) {
                                    _getTapPosition(details);
                                    _showContextMenu(
                                        context, filteredNotes[index]);
                                    selectedIndex = index;
                                    setState(() {});
                                  },
                                  onTap: () {
                                    setState(() {
                                      selectedIndex = index;
                                      isSelected = true;
                                    });
                                  },
                                  child: NoteListItemWidget(
                                      note: filteredNotes[index],
                                      selectedIndex: selectedIndex,
                                      isSelected:
                                          index == selectedIndex && isSelected),
                                );
                              },
                            )
                          : Center(
                              child: Text(Language.get('no_notes')),
                            )),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(
          width: 0.5,
        ),
        Expanded(
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: UniversalPlatform.isWeb
                  ? readerHead
                  : MoveWindow(
                      child: readerHead,
                    ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: isSelected && filteredNotes.isNotEmpty
                      ? SingleChildScrollView(
                          child: Padding(
                            padding: kGlobalOuterPadding * 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    NoteDateWidget(
                                      text: filteredNotes.isEmpty
                                          ? ''
                                          : Utility.formatDateTime(
                                              filteredNotes[selectedIndex]
                                                  .noteDate),
                                    ),
                                    if (filteredNotes.isNotEmpty)
                                      Container(
                                        width: 15,
                                        height: 15,
                                        decoration: BoxDecoration(
                                          color: NoteColor.getColor(
                                              filteredNotes[selectedIndex]
                                                  .noteColor,
                                              false),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 60),
                                  child: MarkdownBody(
                                      selectable: true,
                                      softLineBreak: true,
                                      onTapLink: (text, href, title) =>
                                          _launchUrl(href),
                                      styleSheet: MarkdownStyleSheet(
                                          blockquote: const TextStyle(
                                              color: Colors.black),
                                          blockquoteDecoration:
                                              const BoxDecoration(
                                            color: Colors.transparent,
                                            border: Border(
                                              left: BorderSide(
                                                  color: kPrimaryColor,
                                                  width: 3),
                                            ),
                                          ),
                                          code: const TextStyle(
                                              backgroundColor:
                                                  Colors.transparent),
                                          codeblockAlign:
                                              WrapAlignment.spaceAround,
                                          codeblockDecoration: BoxDecoration(
                                              color: darkModeOn
                                                  ? Colors.white10
                                                  : Colors.black12),
                                          checkbox: const TextStyle(
                                              color: kPrimaryColor)),
                                      data: filteredNotes.isEmpty
                                          ? ''
                                          : filteredNotes[selectedIndex]
                                              .noteText),
                                ),
                              ],
                            ),
                          ),
                        )
                      : EmptyWidget(
                          text: Language.get('select_note'),
                          width: MediaQuery.of(context).size.width * 0.4,
                          asset: 'images/undraw_playful_cat.svg'),
                ),
              ],
            ),
            bottomNavigationBar: Visibility(
              visible: isSelected,
              replacement: Container(),
              child: Container(
                decoration: const BoxDecoration(
                  color: kLightPrimary,
                  border: Border(
                    top: BorderSide(color: kLightStroke, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 6),
                      child: Row(
                        children: [
                          TextButton(
                              onPressed: () {
                                assignFields(filteredNotes[selectedIndex]);
                                showEditDialog(context);
                              },
                              child: const Icon(
                                BootstrapIcons.pencil,
                                size: 18,
                              )),
                          TextButton(
                              onPressed: () => selectColor(
                                  context, filteredNotes[selectedIndex].noteId),
                              child: const Icon(
                                BootstrapIcons.palette2,
                                size: 18,
                              )),
                          TextButton(
                              onPressed: () {},
                              child: const Icon(
                                BootstrapIcons.tags,
                                size: 18,
                              )),
                          TextButton(
                              onPressed: () => confirmDelete(
                                  context, filteredNotes[selectedIndex].noteId),
                              child: const Icon(
                                BootstrapIcons.trash3,
                                size: 18,
                              )),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void assignFields(Notes note) {
    setState(() {
      isNewNote = note.noteId.isEmpty;
      currentNoteId = note.noteId;
      noteTitleController.text = note.noteTitle;
      noteTextController.text = note.noteText;
    });
  }

  void _getTapPosition(TapDownDetails details) {
    final RenderBox referenceBox = context.findRenderObject() as RenderBox;
    setState(() {
      _tapPosition = referenceBox.globalToLocal(details.globalPosition);
    });
  }

  void _showContextMenu(BuildContext context, Notes note) async {
    final RenderObject? overlay =
        Overlay.of(context).context.findRenderObject();
    final result = await showMenu(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(_tapPosition.dx + 140, _tapPosition.dy, 30, 30),
          Rect.fromLTWH(0, 0, overlay!.paintBounds.size.width,
              overlay.paintBounds.size.height),
        ),
        items: List.generate(contextMenuItems.length, (index) {
          return PopupMenuItem(
            height: 35,
            value: contextMenuItems[index].value,
            child: Row(
              children: [
                Expanded(child: Text(contextMenuItems[index].caption)),
                Text(
                  contextMenuItems[index].hint,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          );
        }));
    switch (result) {
      case 'edit':
        assignFields(note);
        if (context.mounted) {
          showEditDialog(context);
        }
        break;
      case 'delete':
        if (context.mounted) confirmDelete(context, note.noteId);
        break;
      case 'color':
        if (context.mounted) selectColor(context, note.noteId);
        break;
      default:
        break;
    }
  }

  Future<void> _launchUrl(url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void showEditDialog(BuildContext context) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 74),
              child: Container(
                padding: kGlobalOuterPadding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: noteTitleController,
                        style: const TextStyle(fontSize: 20.0),
                        decoration: InputDecoration(
                          hintText: Language.get('enter_title'),
                        ),
                      ),
                      kVSpace,
                      Text(
                        '1 ${Language.get('min_ago')}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      kVSpace,
                      Row(
                        children: [
                          const Icon(
                            BootstrapIcons.tag,
                            size: 16,
                          ),
                          const VerticalDivider(color: Colors.black),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(BootstrapIcons.plus),
                          ),
                        ],
                      ),
                      kVSpace,
                      Expanded(
                        child: TextField(
                          controller: noteTextController,
                          decoration: InputDecoration(
                            hintText: Language.get('type_something'),
                          ),
                          expands: true,
                          maxLines: null,
                          spellCheckConfiguration:
                              const SpellCheckConfiguration.disabled(),
                        ),
                      ),
                      kVSpace,
                      Row(
                        children: [
                          // const Icon(
                          //   BootstrapIcons.palette,
                          //   size: 16,
                          // ),
                          const Spacer(),
                          FilledButton.tonal(
                            onPressed: () {
                              if (noteTextController.text.isNotEmpty) {
                                saveNotes();
                              }
                              Navigator.pop(context);
                            },
                            child: Text(Language.get('save')),
                          ),
                          kHSpace,
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(Language.get('cancel')),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  void confirmDelete(BuildContext context, String noteId) {
    showDialog(
        context: context,
        builder: (context) {
          return ScrawlConfirmDialog(
            onAcceptPressed: () {
              deleteNotes(noteId);
              Navigator.pop(context);
            },
            content: Language.get('confirm_delete'),
          );
        });
  }

  void selectColor(BuildContext context, String noteId) async {
    final colorCode = await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Select Color'),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 1),
                            color: NoteColor.getColor(1, false),
                            isSelected: false),
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 2),
                            color: NoteColor.getColor(2, false),
                            isSelected: false),
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 3),
                            color: NoteColor.getColor(3, false),
                            isSelected: false),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 4),
                            color: NoteColor.getColor(4, false),
                            isSelected: false),
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 5),
                            color: NoteColor.getColor(5, false),
                            isSelected: false),
                        ColorPaletteButton(
                            onTap: () => Navigator.pop(context, 6),
                            color: NoteColor.getColor(6, false),
                            isSelected: false),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, 0),
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15.0),
                            border: Border.all(
                                color: darkModeOn
                                    ? Colors.white12
                                    : Colors.black26)),
                        child: const Icon(Icons.block),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
    if (colorCode != null) {
      int index =
          filteredNotes.indexWhere((element) => element.noteId == noteId);
      filteredNotes[index].noteColor = colorCode;
      isNewNote = false;
      currentNoteId = filteredNotes[index].noteId;
      setState(() {});
      syncNotes(filteredNotes[index], '');
    }
  }
}
