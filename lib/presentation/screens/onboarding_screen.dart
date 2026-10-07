import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/diversity_providers.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final Set<String> _selectedArtists = {};
  bool _isSeeding = false;
  final TextEditingController _customArtistController = TextEditingController();

  static const List<String> popularStarterArtists = [
    'Arijit Singh',
    'The Weeknd',
    'Taylor Swift',
    'Diljit Dosanjh',
    'Coldplay',
    'Drake',
    'Ed Sheeran',
    'Shreya Ghoshal',
    'Post Malone',
    'Pritam',
    'Dua Lipa',
    'Kendrick Lamar',
    'Atif Aslam',
    'Billie Eilish',
    'Karan Aujla',
    'Bruno Mars',
  ];

  @override
  void dispose() {
    _customArtistController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_selectedArtists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 artist to personalize your music'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isSeeding = true);
    try {
      final seeder = ref.read(coldStartSeederProvider);
      await seeder.seedFromInitialArtists(_selectedArtists.toList());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding taste profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _addCustomArtist() {
    final text = _customArtistController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedArtists.add(text);
        _customArtistController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Personalize Your Taste',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Choose artists you love',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Softify trains on-device models to personalize recommendations with zero cloud telemetry.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Search / Add custom artist
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customArtistController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add any artist...',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addCustomArtist(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addCustomArtist,
                    icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Popular artists wrap
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      ...popularStarterArtists.map((artist) {
                        final isSelected = _selectedArtists.contains(artist);
                        return FilterChip(
                          label: Text(artist),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedArtists.add(artist);
                              } else {
                                _selectedArtists.remove(artist);
                              }
                            });
                          },
                          backgroundColor: AppTheme.surfaceElevated,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primary : Colors.white12,
                            ),
                          ),
                        );
                      }),
                      ..._selectedArtists
                          .where((a) => !popularStarterArtists.contains(a))
                          .map((artist) {
                        return FilterChip(
                          label: Text(artist),
                          selected: true,
                          onSelected: (selected) {
                            setState(() {
                              _selectedArtists.remove(artist);
                            });
                          },
                          backgroundColor: AppTheme.surfaceElevated,
                          selectedColor: AppTheme.primary,
                          labelStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom continue button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _isSeeding ? null : _completeOnboarding,
                  child: _isSeeding
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          _selectedArtists.isEmpty
                              ? 'Select Artists'
                              : 'Continue with ${_selectedArtists.length} Artist${_selectedArtists.length > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}
