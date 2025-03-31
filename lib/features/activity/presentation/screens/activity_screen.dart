import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';
import 'package:iftook/helpers/app_colors.dart';

class ActivityScreen extends StatefulWidget {
  final bool isCurrentUser;

  const ActivityScreen({super.key, this.isCurrentUser = false});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Updated profile data with real image URLs
  final List<UserProfile> profiles = []; // Empty list to simulate no activities

  void _showAddActivityBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddActivityBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showAddActivityBottomSheet,
            ),
        ],
        elevation: 0,
      ),
      body: profiles.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                return ProfileCard(
                  profile: profiles[index],
                  isCurrentUser: widget.isCurrentUser,
                  onLikePressed: () {
                    setState(() {
                      profiles[index].likes++;
                    });
                  },
                  onDislikePressed: () {
                    setState(() {
                      profiles[index].dislikes++;
                    });
                  },
                  onEditPressed: () {
                    _showEditActivityBottomSheet(profiles[index]);
                  },
                  onDeletePressed: () {
                    _showDeleteConfirmation(index);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 50,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Activities Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isCurrentUser
                  ? 'Share your moments with the community!'
                  : 'This user hasn\'t posted any activities yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            if (widget.isCurrentUser)
              ElevatedButton.icon(
                onPressed: _showAddActivityBottomSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text(
                  'Add Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditActivityBottomSheet(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditActivityBottomSheet(profile: profile),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Activity',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this activity?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                profiles.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLikePressed;
  final VoidCallback onDislikePressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final bool isCurrentUser;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.onLikePressed,
    required this.onDislikePressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.isCurrentUser,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  int _currentImageIndex = 0;
  bool _isLiked = false;
  bool _isDisliked = false;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: widget.profile.imageUrls.length,
                options: CarouselOptions(
                  aspectRatio: 1,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: false,
                  onPageChanged: (index, _) {
                    setState(() => _currentImageIndex = index);
                  },
                ),
                itemBuilder: (context, index, _) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: "${widget.profile.imageUrls[index]}?w=800",
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[850],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[850],
                        child: const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
              // Edit controls overlay
              if (widget.isCurrentUser)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        MaterialButton(
                          minWidth: 0,
                          shape: const CircleBorder(),
                          onPressed: widget.onEditPressed,
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 15,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        MaterialButton(
                          minWidth: 0,
                          shape: const CircleBorder(),
                          onPressed: widget.onDeletePressed,
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      widget.profile.imageUrls.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == entry.key
                            ? AppColors.primaryColor
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: Text(
                        widget.profile.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                          color:
                              _isLiked ? AppColors.primaryColor : Colors.grey,
                          onPressed: () {
                            setState(() {
                              if (!_isLiked) {
                                _isLiked = true;
                                _isDisliked = false;
                                widget.onLikePressed();
                              }
                            });
                          },
                        ),
                        Text(
                          _formatNumber(widget.profile.likes),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isDisliked
                                ? Icons.thumb_down
                                : Icons.thumb_down_outlined,
                          ),
                          color: _isDisliked
                              ? AppColors.primaryColor
                              : Colors.grey,
                          onPressed: () {
                            setState(() {
                              if (!_isDisliked) {
                                _isDisliked = true;
                                _isLiked = false;
                                widget.onDislikePressed();
                              }
                            });
                          },
                        ),
                        Text(
                          _formatNumber(widget.profile.dislikes),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.profile.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddActivityBottomSheet extends StatefulWidget {
  const AddActivityBottomSheet({super.key});

  @override
  State<AddActivityBottomSheet> createState() => _AddActivityBottomSheetState();
}

class _AddActivityBottomSheetState extends State<AddActivityBottomSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  List<String> selectedImages = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: selectedImages.isEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add_photo_alternate,
                            color: Colors.white, size: 40),
                        onPressed: _pickImages,
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == selectedImages.length) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton(
                                icon: const Icon(Icons.add_photo_alternate,
                                    color: Colors.white),
                                onPressed: _pickImages,
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.network(
                                  selectedImages[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      selectedImages.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your post description...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _pickImages() {
    // Implement image picking functionality
    // You can use image_picker package
  }

  void _saveActivity() {
    // Implement save functionality
    if (_descriptionController.text.isNotEmpty && selectedImages.isNotEmpty) {
      // Save logic here
      Navigator.pop(context);
    }
  }
}

class EditActivityBottomSheet extends StatefulWidget {
  final UserProfile profile;

  const EditActivityBottomSheet({
    super.key,
    required this.profile,
  });

  @override
  State<EditActivityBottomSheet> createState() =>
      _EditActivityBottomSheetState();
}

class _EditActivityBottomSheetState extends State<EditActivityBottomSheet> {
  late TextEditingController _descriptionController;
  late List<String> selectedImages;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.profile.description);
    selectedImages = List.from(widget.profile.imageUrls);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == selectedImages.length) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.add_photo_alternate,
                              color: Colors.white),
                          onPressed: _pickImages,
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CachedNetworkImage(
                            imageUrl: "${selectedImages[index]}?w=200",
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[850],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[850],
                              child:
                                  const Icon(Icons.error, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.white),
                            onPressed: () {
                              setState(() {
                                selectedImages.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your post description...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _pickImages() {
    // Implement image picking functionality
    // You can use image_picker package
    setState(() {
      // For demonstration, adding a random image URL
      selectedImages
          .add("https://images.unsplash.com/photo-1517841905240-472988babdf9");
    });
  }

  void _saveActivity() {
    if (_descriptionController.text.isNotEmpty && selectedImages.isNotEmpty) {
      // Here you would typically update the profile in your data source
      widget.profile.description = _descriptionController.text;
      widget.profile.imageUrls = selectedImages;
      Navigator.pop(context);
    }
  }
}
