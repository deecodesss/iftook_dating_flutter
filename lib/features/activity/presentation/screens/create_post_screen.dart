import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/helpers/app_colors.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File? _selectedImageFile;
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;

  Future<void> _pickAndCropImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _createPost() async {
    if (_selectedImageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image.')));
      return;
    }
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a caption.')));
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final uploadResponse = await ApiService.uploadImage(_selectedImageFile!);
      if (!uploadResponse['success']) {
        throw Exception(uploadResponse['message'] ?? 'Image upload failed');
      }
      final String imageUrl = uploadResponse['imageUrl'];

      final postResponse = await ApiService.createPost(
        photoUrl: imageUrl,
        caption: _captionController.text.trim(),
      );

      if (postResponse.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        throw Exception('Failed to create post: ${postResponse.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _createPost,
            child:
                _isPosting
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      'Post',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndCropImage,
              child: Container(
                height:
                    MediaQuery.of(context).size.width *
                    0.8, // Responsive height
                width:
                    MediaQuery.of(context).size.width * 0.8, // Responsive width
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!, width: 1),
                ),
                child:
                    _selectedImageFile != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            11,
                          ), // slightly less than container to show border
                          child: Image.file(
                            _selectedImageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                        : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 50,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryColor,
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // The "Post" button is now in the AppBar's actions
          ],
        ),
      ),
    );
  }
}
