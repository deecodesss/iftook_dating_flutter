import 'dart:convert';
// import 'dart:io'; // No longer directly used here for image picking

import 'package:cached_network_image/cached_network_image.dart';
// import 'package:carousel_slider/carousel_slider.dart'; // Carousel removed for single image post
import 'package:flutter/material.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/activity/data/post_model.dart';
import 'package:iftook/features/profile/data/models/user.dart'; // Import User model
// import 'package:iftook/features/home/presentation/screens/main_home_screen.dart'; // UserProfile is replaced
import 'package:iftook/helpers/app_colors.dart';
// import 'package:image_picker/image_picker.dart'; // No longer used here
import 'package:http/http.dart' as http;
import './create_post_screen.dart'; // Import the new screen
import './edit_post_screen.dart'; // Import the edit screen

class ActivityScreen extends StatefulWidget {
  // final bool isCurrentUser; // Removed
  final String?
      viewingUserId; // If viewing another user's activity, or null for current user's own activity feed

  const ActivityScreen({super.key, this.viewingUserId});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<PostModel> _posts = [];
  bool _isLoading = true;
  String? _currentLoggedInUserId;
  bool _isViewingOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndFetchPosts();
  }

  Future<void> _loadCurrentUserAndFetchPosts() async {
    _currentLoggedInUserId = await SharedPrefs.getUserIdSharedPreference();
    setState(() {
      // Determine if we are viewing the logged-in user's own activity
      // If viewingUserId is null or matches currentLoggedInUserId, it's their own profile.
      _isViewingOwnProfile = widget.viewingUserId == null ||
          widget.viewingUserId == _currentLoggedInUserId;
    });
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response =
          await ApiService.getPosts(); // Fetches all posts initially
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dynamic postsData = data['posts'];

        if (postsData is List) {
          final List<dynamic> postsJson = postsData;
          List<PostModel> allPosts = postsJson
              .map((item) {
                if (item is Map<String, dynamic>) {
                  try {
                    // Ensure user object within post is parsed correctly if available
                    return PostModel.fromJson(item);
                  } catch (e) {
                    print("Error parsing post item: $item, Error: $e");
                    return null;
                  }
                } else {
                  print("Warning: Found non-map item in postsJson: $item");
                  return null;
                }
              })
              .whereType<PostModel>()
              .toList();

          setState(() {
            String? targetUserIdForDisplay =
                widget.viewingUserId ?? _currentLoggedInUserId;
            if (targetUserIdForDisplay != null) {
              _posts = allPosts
                  .where((post) => post.creatorId == targetUserIdForDisplay)
                  .toList();
            } else {
              _posts = allPosts;
            }
          });
        } else {
          setState(() {
            _posts = [];
          });
          print(
              "Warning: 'posts' field from API is not a list or is null. Value: $postsData");
        }
      } else {
        _showErrorSnackbar('Failed to load posts: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackbar('Error fetching posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Modified to navigate to the new screen
  void _navigateToAddActivityScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );

    if (result == true && mounted) {
      _fetchPosts(); // Refresh posts if a new post was successfully created
    }
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
        title: Text(
          // Adjust title based on whose activity is being viewed
          _isViewingOwnProfile ? 'My Activity' : 'Activity',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isViewingOwnProfile)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _navigateToAddActivityScreen, // Updated onPressed
            ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchPosts,
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return ProfileCard(
                        key: ValueKey(post.id),
                        post: post,
                        isCurrentUserPost: post.creatorId != null &&
                            post.creatorId == _currentLoggedInUserId,
                        currentLoggedInUserId: _currentLoggedInUserId,
                        onLikeUnlikeSuccess:
                            (postId, newIsLiked, newLikeCount) {
                          _updatePostLikeStatus(
                              postId, newIsLiked, newLikeCount);
                        },
                        onEditPressed: () {
                          _navigateToEditActivityScreen(post); // Updated call
                        },
                        onDeletePressed: () {
                          _showDeleteConfirmation(post.id);
                        },
                        onCommentPressed: () {
                          _showCommentsBottomSheet(post);
                        },
                      );
                    },
                  ),
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
              _isViewingOwnProfile // Adjust empty state message
                  ? 'Share your moments with the community!'
                  : 'This user hasn\'t posted any activities yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            if (_isViewingOwnProfile)
              ElevatedButton.icon(
                onPressed: _navigateToAddActivityScreen, // Updated onPressed
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon:
                    const Icon(Icons.add_photo_alternate, color: Colors.white),
                label: const Text(
                  'Add Activity',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Modified to navigate to the new EditPostScreen
  void _navigateToEditActivityScreen(PostModel post) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EditPostScreen(post: post)),
    );

    if (result == true && mounted) {
      _fetchPosts(); // Refresh posts if the post was successfully updated
    }
  }

  void _showDeleteConfirmation(String postId) {
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
            onPressed: () async {
              // Ensure onPressed is async
              Navigator.pop(context); // Close dialog
              try {
                final response = await ApiService.deletePost(postId);
                // Add detailed logging
                print(
                    'Delete Post Response Status Code: ${response.statusCode}');
                print('Delete Post Response Body: ${response.body}');

                if (response.statusCode == 200 || response.statusCode == 204) {
                  // Check for 200 or 204
                  await _fetchPosts(); // Await the fetchPosts operation
                  if (mounted) {
                    // Re-check mounted after await
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        // Check mounted again inside the callback
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Post deleted successfully')));
                      }
                    });
                  }
                } else {
                  // _showErrorSnackbar already checks for mounted internally
                  _showErrorSnackbar(
                      'Failed to delete post. Status: ${response.statusCode}, Body: ${response.body}');
                }
              } catch (e) {
                // _showErrorSnackbar already checks for mounted internally
                _showErrorSnackbar('Error deleting post: $e');
              }
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

  // Renamed and modified to update local state instead of full fetch
  void _updatePostLikeStatus(String postId, bool newIsLiked, int newLikeCount) {
    if (_currentLoggedInUserId == null) return;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      setState(() {
        final post = _posts[postIndex];
        List<String> updatedLikes =
            List.from(post.likes); // Create a mutable copy

        if (newIsLiked) {
          if (!updatedLikes.contains(_currentLoggedInUserId!)) {
            updatedLikes.add(_currentLoggedInUserId!);
          }
        } else {
          updatedLikes.remove(_currentLoggedInUserId!);
        }

        _posts[postIndex] = post.copyWith(
          likes: updatedLikes,
          likeCount: newLikeCount, // Use the newLikeCount from the callback
        );
      });
    }
  }

  void _showCommentsBottomSheet(PostModel post) {
    // Implement comments bottom sheet later
    print("Show comments for post ${post.id}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "Comments for ${post.caption}. Count: ${post.comments.length}")),
    );
  }
}

typedef PostLikeUnlikeSuccessCallback = void Function(
    String postId, bool newIsLiked, int newLikeCount);

class ProfileCard extends StatefulWidget {
  final PostModel post;
  final PostLikeUnlikeSuccessCallback onLikeUnlikeSuccess;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onCommentPressed;
  final bool isCurrentUserPost;
  final String? currentLoggedInUserId;

  const ProfileCard({
    super.key,
    required this.post,
    required this.onLikeUnlikeSuccess,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onCommentPressed,
    required this.isCurrentUserPost,
    this.currentLoggedInUserId,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  User? _effectiveUser;
  bool _isLoadingUserDetails = false;

  late bool _isLikedByCurrentUserLocal;
  late int _localLikeCount;
  bool _isLikingUnliking = false; // To prevent rapid clicks

  @override
  void initState() {
    super.initState();
    _resolveUser();
    _isLikedByCurrentUserLocal = widget.currentLoggedInUserId != null &&
        widget.post.likes.contains(widget.currentLoggedInUserId);
    _localLikeCount = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(covariant ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id ||
        widget.post.likeCount != oldWidget.post.likeCount ||
        widget.post.likes != oldWidget.post.likes) {
      _isLikedByCurrentUserLocal = widget.currentLoggedInUserId != null &&
          widget.post.likes.contains(widget.currentLoggedInUserId);
      _localLikeCount = widget.post.likeCount;
    }
    if (widget.post.user != oldWidget.post.user ||
        widget.post.creatorId != oldWidget.post.creatorId) {
      _resolveUser();
    }
  }

  Future<void> _resolveUser() async {
    print("--- _resolveUser called for post ${widget.post.id} ---");

    // If post.user exists AND has photos, use it. Otherwise, try to fetch.
    if (widget.post.user != null &&
        widget.post.user!.photos?.isNotEmpty == true) {
      print(
          "   Condition: widget.post.user is NOT null AND widget.post.user.photos is NOT empty.");
      print("   widget.post.user.photos: ${widget.post.user!.photos}");
      if (mounted) {
        setState(() {
          _effectiveUser = widget.post.user;
          _isLoadingUserDetails = false;
        });
      }
      print(
          "   _effectiveUser set from widget.post.user. Photos: ${_effectiveUser?.photos}");
    } else if (widget.post.creatorId != null) {
      if (widget.post.user != null &&
          widget.post.user!.photos?.isEmpty == true) {
        print(
            "   Condition: widget.post.user exists but photos are empty. Fetching user details for creatorId ${widget.post.creatorId}.");
      } else if (widget.post.user == null) {
        print(
            "   Condition: widget.post.user IS null, widget.post.creatorId is NOT null (${widget.post.creatorId}). Fetching user.");
      } else {
        print(
            "   Condition: Fallback to fetching user by creatorId ${widget.post.creatorId}. widget.post.user might exist but photos check failed or other reason.");
      }

      if (mounted) {
        setState(() {
          _isLoadingUserDetails = true;
        });
      }
      try {
        final http.Response response =
            await ApiService.getUserById(widget.post.creatorId!);

        if (mounted) {
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final User fetchedUser = User.fromJson(data['user'] ?? data);
            print(
                "   Fetched user (ID: ${fetchedUser.sId}) photos for post ${widget.post.id}: ${fetchedUser.photos}");
            setState(() {
              _effectiveUser = fetchedUser;
              _isLoadingUserDetails = false;
            });
            print(
                "   _effectiveUser set from fetchedUser. Photos: ${_effectiveUser?.photos}");
          } else {
            print(
                "   Failed to fetch user details (status code ${response.statusCode}) for post: ${widget.post.id}, UserID: ${widget.post.creatorId}, Body: ${response.body}");
            setState(() {
              _isLoadingUserDetails = false;
            });
          }
        }
      } catch (e) {
        print(
            "   Exception while fetching user details for post: ${widget.post.id}, UserID: ${widget.post.creatorId}, Error: $e");
        if (mounted) {
          setState(() {
            _isLoadingUserDetails = false;
          });
        }
      }
    } else {
      print(
          "   Condition: widget.post.user IS null (or photos empty and no creatorId) AND widget.post.creatorId IS null. Cannot resolve user.");
      if (mounted) {
        setState(() {
          _isLoadingUserDetails = false;
        });
      }
    }
    print("--- _resolveUser finished for post ${widget.post.id} ---");
  }

  Future<void> _toggleLikeOptimistic() async {
    if (_isLikingUnliking || widget.currentLoggedInUserId == null) return;

    setState(() {
      _isLikingUnliking = true;
    });

    final originalLikedStatus = _isLikedByCurrentUserLocal;
    final originalLikeCount = _localLikeCount;

    // Optimistic UI update
    setState(() {
      _isLikedByCurrentUserLocal = !_isLikedByCurrentUserLocal;
      if (_isLikedByCurrentUserLocal) {
        _localLikeCount++;
      } else {
        _localLikeCount--;
      }
    });

    try {
      http.Response response;
      if (_isLikedByCurrentUserLocal) {
        // Action to take based on new state
        response = await ApiService.likePost(widget.post.id);
      } else {
        response = await ApiService.unlikePost(widget.post.id);
      }

      if (response.statusCode == 200) {
        // API call successful, parse the actual like count from response if available
        // For now, we assume our optimistic update is correct or the parent will sync
        // final responseData = jsonDecode(response.body);
        // final int serverLikeCount = responseData['post']?['likes']?.length ?? _localLikeCount; // Example path

        widget.onLikeUnlikeSuccess(widget.post.id, _isLikedByCurrentUserLocal,
            _localLikeCount /* or serverLikeCount */);
      } else {
        // Revert UI on API failure
        setState(() {
          _isLikedByCurrentUserLocal = originalLikedStatus;
          _localLikeCount = originalLikeCount;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to ${originalLikedStatus ? "unlike" : "like"} post.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // Revert UI on exception
      setState(() {
        _isLikedByCurrentUserLocal = originalLikedStatus;
        _localLikeCount = originalLikeCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error ${originalLikedStatus ? "unliking" : "liking"} post.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikingUnliking = false;
        });
      }
    }
  }

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
    // bool isLikedByCurrentUser = widget.currentLoggedInUserId != null &&
    //     widget.post.likes.contains(widget.currentLoggedInUserId); // Use local state now

    final String displayName =
        _effectiveUser?.name ?? widget.post.userName ?? 'User';

    final String placeholderImageUrl = 'https://via.placeholder.com/150';
    String finalImageForAvatar = placeholderImageUrl; // Default to placeholder

    // Determine the best available profile picture URL
    // Primary source is _effectiveUser, which is resolved in _resolveUser
    if (_effectiveUser?.photos?.isNotEmpty == true &&
        _effectiveUser!.photos!.first.isNotEmpty) {
      finalImageForAvatar = _effectiveUser!.photos!.first;
    }
    // Fallback to denormalized userProfilePicture on the post itself,
    // if _effectiveUser (either from post.user or fetched) didn't yield a photo.
    else if (widget.post.userProfilePicture != null &&
        widget.post.userProfilePicture!.isNotEmpty) {
      finalImageForAvatar = widget.post.userProfilePicture!;
    }
    // If none of the above conditions are met, finalImageForAvatar remains placeholderImageUrl

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6), // Reduced margin
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
              // Post Image
              ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1, // 1:1 ratio for square image
                    child: CachedNetworkImage(
                      imageUrl: widget.post.photo,
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
                  )),

              // Header with User Info and Edit/Delete buttons
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.0)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _isLoadingUserDetails
                              ? CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey[700],
                                  child: const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                                )
                              : CircleAvatar(
                                  radius: 18,
                                  backgroundImage: NetworkImage(
                                      finalImageForAvatar), // Use NetworkImage
                                  // Optional: Add error handling for NetworkImage if needed,
                                  // though CircleAvatar will show its background color or child if the image fails.
                                  onBackgroundImageError:
                                      (exception, stackTrace) {
                                    print(
                                        'Error loading image for avatar: $finalImageForAvatar, Error: $exception');
                                    // You could force showing the placeholder icon here if needed,
                                    // but the child logic below should already handle it if finalImageForAvatar IS the placeholder.
                                  },
                                  child: finalImageForAvatar ==
                                              placeholderImageUrl &&
                                          !_isLoadingUserDetails
                                      ? const Icon(Icons.person,
                                          size:
                                              18) // Show icon if using placeholder and not loading
                                      : null,
                                ),
                          const SizedBox(width: 8),
                          Text(
                            displayName, // This displayName is for the header
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 2.0, color: Colors.black38)
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.isCurrentUserPost)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MaterialButton(
                                minWidth: 0,
                                padding: const EdgeInsets.all(8),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: const CircleBorder(),
                                onPressed: widget.onEditPressed,
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 15,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              MaterialButton(
                                minWidth: 0,
                                padding: const EdgeInsets.all(8),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: const CircleBorder(),
                                onPressed: widget.onDeletePressed,
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12.0, vertical: 8.0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons (Like, Comment)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
                        },
                        child: Icon(
                          _isLikedByCurrentUserLocal // Use local state
                              ? Icons.favorite
                              : Icons.favorite_border,
                          key: ValueKey<bool>(
                              _isLikedByCurrentUserLocal), // Add key for AnimatedSwitcher
                          size: 26,
                        ),
                      ),
                      color: _isLikedByCurrentUserLocal // Use local state
                          ? AppColors.primaryColor
                          : Colors.grey[300],
                      onPressed: _toggleLikeOptimistic,
                    ),
                    const SizedBox(width: 8), // Reduced width from 12 to 8
                    // IconButton(
                    //   padding: EdgeInsets.zero,
                    //   constraints: const BoxConstraints(),
                    //   icon: Icon(Icons.chat_bubble_outline, // Changed icon
                    //       size: 22,
                    //       color: Colors.grey[300]),
                    //   onPressed: widget.onCommentPressed,
                    // ),
                    // Potentially add Share button here
                  ],
                ),
                const SizedBox(height: 6), // Reduced gap

                // Like count
                if (_localLikeCount > 0) // Use local state
                  Text(
                    "${_formatNumber(_localLikeCount)} like${_localLikeCount == 1 ? '' : 's'}", // Use local state
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13), // Slightly smaller
                  ),
                const SizedBox(height: 4), // Reduced gap

                // Caption
                if (widget.post.caption.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      // Removed the displayName TextSpan from here
                      text: widget.post.caption, // Display only the caption
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                  ),
                if (widget.post.caption.isNotEmpty)
                  const SizedBox(height: 4), // Reduced gap if caption exists

                // Comment count / View all comments
                if (widget.post.comments.isNotEmpty)
                  GestureDetector(
                    onTap: widget.onCommentPressed,
                    child: Text(
                      "View all ${_formatNumber(widget.post.comments.length)} comment${widget.post.comments.length == 1 ? '' : 's'}",
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12), // Slightly smaller
                    ),
                  ),
                if (widget.post.comments.isNotEmpty)
                  const SizedBox(height: 4), // Reduced gap if comments exist

                // Timestamp (Example)
                Text(
                  _formatTimestamp(widget.post.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format timestamp (Example implementation)
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
