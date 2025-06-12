import 'package:iftook/features/profile/data/models/user.dart';

class PostModel {
  final String id;
  final User? user; // User who created the post - Changed to User
  final String? creatorId; // Stores the raw ID string of the creator
  final String photo;
  final String caption;
  final List<String> likes; // List of user IDs who liked
  final List<CommentModel> comments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName; // Denormalized for easier display
  final String? userProfilePicture;

  PostModel({
    required this.id,
    this.user,
    this.creatorId,
    required this.photo,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userProfilePicture,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    User? postCreator;
    String? pUserName;
    String? pUserProfilePic;
    String? rawCreatorId;

    if (json['userId'] != null) {
      if (json['userId'] is Map<String, dynamic>) {
        // userId is a populated object
        final userIdMap = json['userId'] as Map<String, dynamic>;
        if (userIdMap['_id'] != null) {
          postCreator = User.fromJson(userIdMap);
          pUserName = postCreator.name;
          pUserProfilePic = postCreator.photos?.isNotEmpty == true
              ? postCreator.photos!.first
              : null;
          rawCreatorId = postCreator.sId;
        }
      } else if (json['userId'] is String) {
        // userId is just an ID string
        rawCreatorId = json['userId'] as String;
        // pUserName and pUserProfilePic would be null here unless fetched separately
        // or if the backend also sends denormalized name/pic alongside the string ID.
      }
    }

    return PostModel(
      id: json['_id'] as String,
      user: postCreator,
      creatorId: rawCreatorId, // Assign the raw creator ID
      photo: json['photo'] as String,
      caption: json['caption'] as String? ?? '',
      likes: (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => CommentModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userName: pUserName,
      userProfilePicture: pUserProfilePic,
    );
  }

  int get likeCount => likes.length;

  // Add this copyWith method
  PostModel copyWith({
    String? id,
    String? photo,
    String? caption,
    String? creatorId,
    String? userName,
    String? userProfilePicture,
    User? user,
    List<String>? likes,
    int? likeCount,
    List<CommentModel>? comments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      photo: photo ?? this.photo,
      caption: caption ?? this.caption,
      creatorId: creatorId ?? this.creatorId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      user: user ?? this.user,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CommentModel {
  final String id;
  final User? user; // User who commented - Changed to User
  final String? commenterId; // Stores the raw ID string of the commenter
  final String text;
  final DateTime createdAt;
  final String? userName; // Denormalized
  final String? userProfilePicture; // Denormalized

  CommentModel({
    required this.id,
    this.user,
    this.commenterId,
    required this.text,
    required this.createdAt,
    this.userName,
    this.userProfilePicture,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    User? commentAuthor;
    String? cUserName;
    String? cUserProfilePic;
    String? rawCommenterId;

    if (json['user'] != null) {
      if (json['user'] is Map<String, dynamic>) {
        final userMap = json['user'] as Map<String, dynamic>;
        if (userMap['_id'] != null) {
          commentAuthor = User.fromJson(userMap);
          cUserName = commentAuthor.name;
          cUserProfilePic = commentAuthor.photos?.isNotEmpty == true
              ? commentAuthor.photos!.first
              : null;
          rawCommenterId = commentAuthor.sId;
        }
      } else if (json['user'] is String) {
        rawCommenterId = json['user'] as String;
      }
    }
    return CommentModel(
      id: json['_id'] as String,
      user: commentAuthor,
      commenterId: rawCommenterId,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userName: cUserName,
      userProfilePicture: cUserProfilePic,
    );
  }
}
