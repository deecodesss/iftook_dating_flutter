class User {
  Location? location;
  PanDetails? panDetails;
  Earnings? earnings;
  String? sId;
  String? name;
  String? email;
  String? dob;
  String? gender;
  String? interestedIn;
  String? about;
  String? profession;
  String? height;
  List<String>? languages;
  List<String>? photos;
  List<String>? interests;
  bool? isOnline;
  String? role;
  List<Null>? likes;
  List<Null>? dislikes;
  List<Null>? matches;
  String? createdAt;
  String? updatedAt;
  dynamic iV;
  dynamic? walletBalance;
  bool? isBlocked;
  String? blockReason;
  bool? isPromoted;
  dynamic? averageRating;
  List<Reviews>? reviews;
  bool? isFriend;

  User(
      {this.location,
      this.panDetails,
      this.earnings,
      this.sId,
      this.name,
      this.email,
      this.dob,
      this.gender,
      this.interestedIn,
      this.about,
      this.profession,
      this.height,
      this.languages,
      this.photos,
      this.interests,
      this.isOnline,
      this.role,
      this.likes,
      this.dislikes,
      this.matches,
      this.createdAt,
      this.updatedAt,
      this.iV,
      this.walletBalance,
      this.isBlocked,
      this.blockReason,
      this.isPromoted,
      this.averageRating,
      this.isFriend,
      this.reviews});

  User.fromJson(Map<String, dynamic> json) {
    location = json['location'] != null
        ? new Location.fromJson(json['location'])
        : null;
    panDetails = json['panDetails'] != null
        ? new PanDetails.fromJson(json['panDetails'])
        : null;
    earnings = json['earnings'] != null
        ? new Earnings.fromJson(json['earnings'])
        : null;
    sId = json['_id'];
    name = json['name'];
    isFriend = json['isFriend'];
    email = json['email'];
    dob = json['dob'];
    gender = json['gender'];
    interestedIn = json['interestedIn'];
    about = json['about'];
    profession = json['profession'];
    height = json['height'];
    languages = json['languages'].cast<String>();
    photos = json['photos'].cast<String>();
    interests = json['interests'].cast<String>();
    isOnline = json['isOnline'];
    role = json['role'];
    // if (json['likes'] != null) {
    //   likes = <Null>[];
    //   json['likes'].forEach((v) {
    //     likes!.add(new Null.fromJson(v));
    //   });
    // }
    // if (json['dislikes'] != null) {
    //   dislikes = <Null>[];
    //   json['dislikes'].forEach((v) {
    //     dislikes!.add(new Null.fromJson(v));
    //   });
    // }
    // if (json['matches'] != null) {
    //   matches = <Null>[];
    //   json['matches'].forEach((v) {
    //     matches!.add(new Null.fromJson(v));
    //   });
    // }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    walletBalance = json['walletBalance'];
    isBlocked = json['isBlocked'];
    blockReason = json['blockReason'];
    isPromoted = json['isPromoted'];
    averageRating = json['averageRating'];
    if (json['reviews'] != null) {
      reviews = <Reviews>[];
      json['reviews'].forEach((v) {
        reviews!.add(new Reviews.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.location != null) {
      data['location'] = this.location!.toJson();
    }
    if (this.panDetails != null) {
      data['panDetails'] = this.panDetails!.toJson();
    }
    if (this.earnings != null) {
      data['earnings'] = this.earnings!.toJson();
    }
    data['_id'] = this.sId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['dob'] = this.dob;
    data['gender'] = this.gender;
    data['interestedIn'] = this.interestedIn;
    data['about'] = this.about;
    data['profession'] = this.profession;
    data['height'] = this.height;
    data['languages'] = this.languages;
    data['isFriend'] = this.isFriend;
    data['photos'] = this.photos;
    data['interests'] = this.interests;
    data['isOnline'] = this.isOnline;
    data['role'] = this.role;
    // if (this.likes != null) {
    //   data['likes'] = this.likes!.map((v) => v.toJson()).toList();
    // }
    // if (this.dislikes != null) {
    //   data['dislikes'] = this.dislikes!.map((v) => v.toJson()).toList();
    // }
    // if (this.matches != null) {
    //   data['matches'] = this.matches!.map((v) => v.toJson()).toList();
    // }
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['__v'] = this.iV;
    data['walletBalance'] = this.walletBalance;
    data['isBlocked'] = this.isBlocked;
    data['blockReason'] = this.blockReason;
    data['isPromoted'] = this.isPromoted;
    data['averageRating'] = this.averageRating;
    if (this.reviews != null) {
      data['reviews'] = this.reviews!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Location {
  String? country;
  String? state;
  String? city;

  Location({this.country, this.state, this.city});

  Location.fromJson(Map<String, dynamic> json) {
    country = json['country'];
    state = json['state'];
    city = json['city'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['country'] = this.country;
    data['state'] = this.state;
    data['city'] = this.city;
    return data;
  }
}

class PanDetails {
  String? panNumber;
  String? panImage;

  PanDetails({this.panNumber, this.panImage});

  PanDetails.fromJson(Map<String, dynamic> json) {
    panNumber = json['panNumber'];
    panImage = json['panImage'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['panNumber'] = this.panNumber;
    data['panImage'] = this.panImage;
    return data;
  }
}

class Earnings {
  dynamic chat;
  dynamic voice;
  dynamic video;
  dynamic live;
  dynamic subscription;

  Earnings({this.chat, this.voice, this.video, this.live, this.subscription});

  Earnings.fromJson(Map<String, dynamic> json) {
    chat = json['chat'];
    voice = json['voice'];
    video = json['video'];
    live = json['live'];
    subscription = json['subscription'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['chat'] = this.chat;
    data['voice'] = this.voice;
    data['video'] = this.video;
    data['live'] = this.live;
    data['subscription'] = this.subscription;
    return data;
  }
}

class Reviews {
  String? user;
  dynamic rating;
  String? comment;
  String? sId;
  String? createdAt;

  Reviews({this.user, this.rating, this.comment, this.sId, this.createdAt});

  Reviews.fromJson(Map<String, dynamic> json) {
    user = json['user'];
    rating = json['rating'];
    comment = json['comment'];
    sId = json['_id'];
    createdAt = json['createdAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['user'] = this.user;
    data['rating'] = this.rating;
    data['comment'] = this.comment;
    data['_id'] = this.sId;
    data['createdAt'] = this.createdAt;
    return data;
  }
}
