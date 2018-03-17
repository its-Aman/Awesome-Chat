import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

//imagePicker
import 'package:image_picker/image_picker.dart';

//firebase
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';

//global variables for firebase
final analytics = new FirebaseAnalytics();
final googleSignIn = new GoogleSignIn();
final auth = FirebaseAuth.instance;
final reference = FirebaseDatabase.instance.reference().child('messages');

void main() => runApp(new FriendlyChatApp());

class FriendlyChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Awesome Chat",
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: new ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  State createState() => new ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  // final List<ChatMessage> _message = <ChatMessage>[];

  final TextEditingController _textEditingController =
      new TextEditingController();

  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Awesome Chat"),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: new Container(
          child: new Column(
            children: <Widget>[
              new Flexible(
                child: new FirebaseAnimatedList(
                  query: reference,
                  sort: (a, b) => b.key.compareTo(a.key),
                  padding: new EdgeInsets.all(8.0),
                  reverse: true,
                  itemBuilder:
                      (_, DataSnapshot snapshot, Animation<double> animation) {
                    return new ChatMessage(
                        snapshot: snapshot, animation: animation);
                  },
                ),
                // child: new ListView.builder(
                //   padding: const EdgeInsets.all(8.0),
                //   reverse: true,
                //   itemBuilder: (_, int index) => _message[index],
                //   itemCount: _message.length,
                // ),
              ),
              new Divider(height: 1.0),
              new Container(
                decoration:
                    new BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              )
            ],
          ),
          decoration: Theme.of(context).platform == TargetPlatform.iOS
              ? new BoxDecoration(
                  border:
                      new Border(top: new BorderSide(color: Colors.grey[200])),
                )
              : null),
    );
  }

  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: new Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Row(
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: new IconButton(
                icon: new Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensuredLoggedIn();
                  File imageFile = await ImagePicker.pickImage();
                  print(imageFile);
                  int random = new Random().nextInt(1000000);
                  StorageReference ref =
                      FirebaseStorage.instance.ref().child("image$random.jpg");
                  StorageUploadTask uploadTask = ref.put(imageFile);
                  Uri downloadUrl = (await uploadTask.future).downloadUrl;
                  _sendMessage(imageUrl: downloadUrl.toString());
                  print(downloadUrl);
                },
              ),
            ),
            new Flexible(
              child: new TextField(
                controller: _textEditingController,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: _isComposing ? _handleSubmitted : null,
                decoration:
                    new InputDecoration.collapsed(hintText: "Send a message"),
              ),
            ),
            new Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? new CupertinoButton(
                        child: new Text("Send"),
                        onPressed: _isComposing
                            ? () =>
                                _handleSubmitted(_textEditingController.text)
                            : null)
                    : new IconButton(
                        icon: new Icon(Icons.send),
                        onPressed: _isComposing
                            ? () =>
                                _handleSubmitted(_textEditingController.text)
                            : null))
          ],
        ),
      ),
    );
  }

  Future<Null> _handleSubmitted(String text) async {
    print(text);
    this._textEditingController.clear();
    setState(() {
      _isComposing = false;
    });
    await _ensuredLoggedIn();
    _sendMessage(text: text);
  }

  void _sendMessage({String text, String imageUrl}) {
    print('in _sendMsssage');
    print(text);
    print(imageUrl);

    reference.push().set({
      'text': text,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl
    });

    // ChatMessage message = new ChatMessage(
    //   text: text,
    //   animationController: new AnimationController(
    //       duration: new Duration(milliseconds: 700), vsync: this),
    // );
    // setState(() {
    //   _message.insert(0, message);
    // });
    // message.animationController.forward();
    analytics.logEvent(name: "send_message");
  }

  // @override
  // void dispose() {
  //   for (ChatMessage message in _message) {
  //     message.animation.dispose();
  //   }
  //   super.dispose();
  // }
}

class ChatMessage extends StatelessWidget {
  final DataSnapshot snapshot;
  final Animation animation;

  ChatMessage({this.snapshot, this.animation});

  @override
  Widget build(BuildContext context) {
    return new SizeTransition(
      sizeFactor:
          new CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
      axisAlignment: 0.0,
      child: new Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: new CircleAvatar(
                  // child: new Text(googleSignIn.currentUser.displayName[0]),
                  backgroundImage:
                      new NetworkImage(snapshot.value['senderPhotoUrl'])),
            ),
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(snapshot.value['senderName'],
                      style: Theme.of(context).textTheme.subhead),
                  new Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: snapshot.value['imageUrl'] != null
                        ? new Image.network(snapshot.value['imageUrl'],
                            width: 250.0)
                        : new Text(snapshot.value['text']),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

final ThemeData kIOSTheme = new ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = new ThemeData(
    primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]);

//2nd tute

Future<Null> _ensuredLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently();
  }
  if (user == null) {
    await googleSignIn.signIn();
    analytics.logLogin();
  }
  print(googleSignIn.currentUser);

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}
