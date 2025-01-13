import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';

import 'main_home_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<UserProfile> _searchResults = [];
  final List<String> _recentSearches = [];
  final List<UserProfile> _profiles = [
    UserProfile(
        name: 'Priya Sharma',
        age: 25,
        description:
            'Tech enthusiast and yoga instructor. Love exploring new cafes and reading science fiction.',
        imageUrls: [
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9'
        ],
        location: 'Mumbai',
        profession: 'Software Engineer',
        rating: 4.8,
        reviewCount: 156,
        likes: 3200,
        dislikes: 45,
        reviews: [
          Review(
              name: "Rahul M.",
              comment: "Great conversation about tech and startups!",
              rating: 5.0,
              date: "2 days ago"),
          Review(
              name: "Anjali K.",
              comment: "Very knowledgeable and friendly",
              rating: 4.5,
              date: "1 week ago")
        ]),
    UserProfile(
        name: 'Aditya Patel',
        age: 28,
        description:
            'Startup founder by day, musician by night. Looking for someone who shares my passion for innovation and art.',
        imageUrls: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
          'https://images.unsplash.com/photo-1568602471122-7832951cc4c5',
          'https://images.unsplash.com/photo-1564564321837-a57b7070ac4f'
        ],
        location: 'Bangalore',
        profession: 'Entrepreneur',
        rating: 4.6,
        reviewCount: 142,
        likes: 2800,
        dislikes: 32,
        reviews: [
          Review(
              name: "Sneha R.",
              comment: "Inspiring conversations about business and music",
              rating: 4.5,
              date: "3 days ago")
        ]),
    UserProfile(
      name: 'Zara Khan',
      age: 24,
      description:
          'Fashion blogger and digital content creator. Always hunting for the perfect shot and the perfect cup of coffee.',
      imageUrls: [
        'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43',
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
        'https://images.unsplash.com/photo-1535324492437-d8dea70a38a7'
      ],
      location: 'Delhi',
      profession: 'Content Creator',
      rating: 4.9,
      reviewCount: 198,
      likes: 4500,
      dislikes: 28,
    ),
    UserProfile(
      name: 'Vikram Singh',
      age: 30,
      description:
          'Chef and food photographer. Believer in sustainable cooking and farm-to-table philosophy.',
      imageUrls: [
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
        'https://images.unsplash.com/photo-1480429370139-e0132c086e2a',
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce'
      ],
      location: 'Pune',
      profession: 'Chef',
      rating: 4.7,
      reviewCount: 165,
      likes: 2900,
      dislikes: 34,
    ),
    UserProfile(
      name: 'Anjali Desai',
      age: 26,
      description:
          'Environmental lawyer fighting for climate justice. Avid trekker and amateur astronomer.',
      imageUrls: [
        'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'https://images.unsplash.com/photo-1526510747491-58f928ec870f'
      ],
      location: 'Chennai',
      profession: 'Lawyer',
      rating: 4.4,
      reviewCount: 112,
      likes: 1900,
      dislikes: 41,
    ),
    UserProfile(
      name: 'Arjun Menon',
      age: 29,
      description:
          'Product designer with a passion for minimalism. Part-time surfer and full-time dog parent.',
      imageUrls: [
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        'https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f',
        'https://images.unsplash.com/photo-1492446845049-9c50cc313f00'
      ],
      location: 'Goa',
      profession: 'Product Designer',
      rating: 4.3,
      reviewCount: 134,
      likes: 2100,
      dislikes: 38,
    ),
    UserProfile(
      name: 'Maya Reddy',
      age: 27,
      description:
          'Classical dancer and dance therapist. Believe in the healing power of movement and expression.',
      imageUrls: [
        'https://images.unsplash.com/photo-1534751516642-a1af1ef26a56',
        'https://images.unsplash.com/photo-1524502397800-2eeaad7c3fe5',
        'https://images.unsplash.com/photo-1526510747491-58f928ec870f'
      ],
      location: 'Hyderabad',
      profession: 'Dance Therapist',
      rating: 4.8,
      reviewCount: 178,
      likes: 3100,
      dislikes: 25,
    ),
    UserProfile(
      name: 'Kabir Bhat',
      age: 31,
      description:
          'Travel photographer documenting cultures around India. Always ready for the next adventure.',
      imageUrls: [
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
        'https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f',
        'https://images.unsplash.com/photo-1492446845049-9c50cc313f00'
      ],
      location: 'Kolkata',
      profession: 'Photographer',
      rating: 4.6,
      reviewCount: 145,
      likes: 2600,
      dislikes: 29,
    ),
  ];
  void _performSearch(String query) {
    // Mock search functionality - replace with actual implementation
    setState(() {
      _searchResults.clear();
      if (query.isNotEmpty) {
        _searchResults.addAll(_profiles.where((profile) =>
            profile.name.toLowerCase().contains(query.toLowerCase()) ||
            profile.profession.toLowerCase().contains(query.toLowerCase()) ||
            profile.location.toLowerCase().contains(query.toLowerCase())));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            prefixIcon:
                Icon(HugeIcons.strokeRoundedSearch01, color: Colors.grey[400]),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: Colors.grey[400]),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
          ),
          onChanged: _performSearch,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchController.text.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recent Searches',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(Icons.history, color: Colors.grey[400]),
                  title: Text(
                    _recentSearches[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _searchController.text = _recentSearches[index];
                    _performSearch(_recentSearches[index]);
                  },
                );
              },
            ),
          ] else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final profile = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(profile.imageUrls[0]),
                    ),
                    title: Text(
                      '${profile.name}, ${profile.age}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${profile.profession} • ${profile.location}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    onTap: () {
                      Get.to(() => UserProfileScreen());
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
