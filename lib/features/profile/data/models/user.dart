class User {
  Location? location;
  PanDetails? panDetails;
  BankDetails? bankDetails; // Added bank details
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
  List<String>? wishlist;
  List<String>? interests;
  bool? isOnline;
  String? role;
  List<Null>? likes;
  List<Null>? dislikes;
  List<Null>? matches;
  String? createdAt;
  String? updatedAt;
  dynamic iV;
  dynamic walletBalance; // Change to dynamic to handle both int and double
  bool? isBlocked;
  String? blockReason;
  bool? isPromoted;
  dynamic? averageRating;
  List<Reviews>? reviews;
  bool? isFriend;

  User({
    this.location,
    this.panDetails,
    this.bankDetails, // Added bank details
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
    this.walletBalance = 0,
    this.isBlocked,
    this.blockReason,
    this.isPromoted,
    this.averageRating,
    this.isFriend,
    this.reviews,
    this.wishlist,
  });

  User.fromJson(Map<String, dynamic> json) {
    location = json['location'] != null
        ? new Location.fromJson(json['location'])
        : null;
    panDetails = json['panDetails'] != null
        ? new PanDetails.fromJson(json['panDetails'])
        : null;
    bankDetails = json['bankDetails'] != null
        ? new BankDetails.fromJson(json['bankDetails'])
        : null; // Added bank details parsing
    earnings = json['earnings'] != null
        ? Earnings.fromJson(json['earnings'])
        : Earnings(
            chat: 150, // Default values
            voice: 300,
            video: 450,
            live: 5,
            subscription: 700,
          );
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
    wishlist = json['wishlist'].cast<String>();
    interests = json['interests'].cast<String>();
    isOnline = json['isOnline'];
    role = json['role'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    walletBalance = json['walletBalance'] != null
        ? (json['walletBalance'] as num).toDouble()
        : 0.0;
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
    if (this.bankDetails != null) {
      data['bankDetails'] =
          this.bankDetails!.toJson(); // Added bank details serialization
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
    data['wishlist'] = this.wishlist;
    data['interests'] = this.interests;
    data['isOnline'] = this.isOnline;
    data['role'] = this.role;
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

  User copyWith({
    String? sId,
    String? name,
    String? email,
    String? phone,
    String? dob,
    String? gender,
    String? profession,
    bool? isFriend,
    List<String>? photos,
    Location? location,
  }) {
    return User(
      sId: sId ?? this.sId,
      name: name ?? this.name,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      isFriend: isFriend ?? this.isFriend,
      photos: photos ?? this.photos,
      location: location ?? this.location,
    );
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
  final num chat;
  final num voice;
  final num video;
  final num live;
  final num subscription;

  Earnings({
    this.chat = 150,
    this.voice = 300,
    this.video = 450,
    this.live = 5,
    this.subscription = 700,
  });

  factory Earnings.fromJson(Map<String, dynamic> json) {
    return Earnings(
      chat: json['chat'] ?? 150,
      voice: json['voice'] ?? 300,
      video: json['video'] ?? 450,
      live: json['live'] ?? 5,
      subscription: json['subscription'] ?? 700,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat': chat,
      'voice': voice,
      'video': video,
      'live': live,
      'subscription': subscription,
    };
  }

  // Add toDouble methods for safe conversion
  double get chatRate => chat.toDouble();
  double get voiceRate => voice.toDouble();
  double get videoRate => video.toDouble();
  double get liveRate => live.toDouble();
  double get subscriptionRate => subscription.toDouble();
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

class UserEarnings {
  final double chat;
  final double voice;
  final double video;
  final double live;
  final double subscription;

  UserEarnings({
    this.chat = 140,
    this.voice = 290,
    this.video = 440,
    this.live = 5,
    this.subscription = 700,
  });

  factory UserEarnings.fromJson(Map<String, dynamic> json) {
    return UserEarnings(
      chat: (json['chat'] ?? 140).toDouble(),
      voice: (json['voice'] ?? 290).toDouble(),
      video: (json['video'] ?? 440).toDouble(),
      live: (json['live'] ?? 5).toDouble(),
      subscription: (json['subscription'] ?? 700).toDouble(),
    );
  }
}

// Added new class for bank details
class BankDetails {
  String? accountType;
  String? accountHolderName;
  String? bankName;
  String? accountNumber;
  // For Indian Banks
  String? ifscCode;
  // For International Banks
  String? swiftCode;
  String? iban;
  String? routingNumber;
  bool? isVerified;

  BankDetails({
    this.accountType,
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.swiftCode,
    this.iban,
    this.routingNumber,
    this.isVerified = false,
  });

  BankDetails.fromJson(Map<String, dynamic> json) {
    accountType = json['accountType'];
    accountHolderName = json['accountHolderName'];
    bankName = json['bankName'];
    accountNumber = json['accountNumber'];
    ifscCode = json['ifscCode'];
    swiftCode = json['swiftCode'];
    iban = json['iban'];
    routingNumber = json['routingNumber'];
    isVerified = json['isVerified'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['accountType'] = this.accountType;
    data['accountHolderName'] = this.accountHolderName;
    data['bankName'] = this.bankName;
    data['accountNumber'] = this.accountNumber;
    if (this.ifscCode != null) data['ifscCode'] = this.ifscCode;
    if (this.swiftCode != null) data['swiftCode'] = this.swiftCode;
    if (this.iban != null) data['iban'] = this.iban;
    if (this.routingNumber != null) data['routingNumber'] = this.routingNumber;
    data['isVerified'] = this.isVerified;
    return data;
  }
}
