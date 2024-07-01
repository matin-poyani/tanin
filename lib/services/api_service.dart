import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/music_track.dart';

class MusicApiService extends GetxController {
  final RxList<MusicTrack> _musicTracks = <MusicTrack>[].obs;
  final RxMap<String, List<MusicTrack>> _categoryTracks = <String, List<MusicTrack>>{}.obs;
  final RxList<String> _categories = <String>[].obs;
  final RxList<String> _suggestions = <String>[].obs;
  final RxString _searchValue = ''.obs;
  final TextEditingController textEditingController = TextEditingController();
  final RxList<String> searchHistory = ["Fall out boy", "Good girl"].obs;
  final RxList<String> topSearches = ["Girl generation", "Imagine Dragons"].obs;
  final RxList<MusicTrack> searchResults = <MusicTrack>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt _currentPage = 1.obs;
  final RxBool hasMore = true.obs;

  // کش برای داده‌های موزیک
  final Map<String, List<MusicTrack>> _cachedCategoryTracks = {};

  List<MusicTrack> get musicTracks => _musicTracks.toList();
  List<String> get categories => _categories.toList();
  List<String> get suggestions => _suggestions.toList();
  String get searchValue => _searchValue.value;
  Map<String, List<MusicTrack>> get categoryTracks => _categoryTracks;

  List<MusicTrack> getCategoryTracks(String category) => _categoryTracks[category]?.toList() ?? [];

  @override
  void onInit() {
    super.onInit();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('https://avvangmusic.ir/Api/Categorys'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        _categories.assignAll(data.map((e) => e['Name'].toString()).toList());
        await fetchCategoryTracks();  // فراخوانی برای دریافت موزیک‌ها
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  Future<List<MusicTrack>> fetchCategoryTracks() async {
    if (!hasMore.value) return [];

    try {
      List<Future<http.Response>> futures = _categories.asMap().entries.map((entry) {
        int index = entry.key;
        String category = entry.value;
        return http.get(Uri.parse('https://avvangmusic.ir/Api/musicCat/${index + 1}?page=${_currentPage.value}'));
      }).toList();

      final responses = await Future.wait(futures);

      List<MusicTrack> allTracks = [];
      for (var i = 0; i < responses.length; i++) {
        if (responses[i].statusCode == 200) {
          List<dynamic> data = json.decode(responses[i].body);
          List<MusicTrack> tracks = data.map((e) => MusicTrack.fromJson(e)).toList();
          if (tracks.isEmpty) {
            hasMore.value = false;
          } else {
            String category = _categories[i];
            _categoryTracks[category] = (_categoryTracks[category] ?? []) + tracks;
            _cachedCategoryTracks[category] = tracks;  // کش کردن داده‌های دریافت شده
            allTracks.addAll(tracks);
          }
        } else {
          throw Exception('Failed to load data for category ${_categories[i]}');
        }
      }

      _currentPage.value++;
      return allTracks;  // باید لیستی از ترک‌ها را برگرداند
    } catch (e) {
      print('Error fetching tracks for categories: $e');
      rethrow;
    }
  }

  Future<void> fetchSuggestions(String searchValue) async {
    _searchValue.value = searchValue;
    try {
      List<MusicTrack> allTracks = [..._musicTracks, ..._categoryTracks.values.expand((x) => x)];
      final List<MusicTrack> filteredTracks = allTracks
          .where((track) => track.title.toLowerCase().contains(searchValue.toLowerCase()))
          .toList();
      _suggestions.assignAll(filteredTracks.map((track) => track.title).toList());
      // searchResults.assignAll(filteredTracks);  // ذخیره کردن نتیجه جستجو
    } catch (e) {
      _suggestions.clear();
      print('Error fetching suggestions: $e');
      rethrow;
    }
  }



  Future<List<MusicTrack>> fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://avvangmusic.ir/api/index'));
      if (response.statusCode == 200) {
        String responseBody = response.body;
        print('Response body: $responseBody');
        List<dynamic> data = json.decode(response.body);
        print('Decoded JSON: $data');
        List<MusicTrack> tracks = data.map((e) => MusicTrack.fromJson(e)).toList();
        print('Parsed tracks: $tracks');
        _musicTracks.assignAll(tracks);
        print('Fetched ${tracks.length} tracks.');
        return tracks;  // باید لیستی از ترک‌ها را برگرداند
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error fetching data: $e');
      rethrow;
    }
  }

  Future<void> searchMusic(String query) async {
    isLoading(true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://avvangmusic.ir/Api/Index?query=$query')),
        http.get(Uri.parse('https://avvangmusic.ir/Api/Index?page=&query=$query')),
        http.get(Uri.parse('https://avvangmusic.ir/Api/Categorys?query=$query')),
      ]);

      final allData = responses
          .where((response) => response.statusCode == 200)
          .expand((response) {
        List<dynamic> data = json.decode(response.body);
        return data;
      })
          .toList();

      List<MusicTrack> tracks = allData.map((e) => MusicTrack.fromJson(e)).toList();
      searchResults.value = tracks;

    } catch (e) {
      print('Error fetching search results: $e');
      rethrow;
    } finally {
      isLoading(false);
    }
  }
}
