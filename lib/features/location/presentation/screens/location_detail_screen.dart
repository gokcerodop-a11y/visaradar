import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/weather_service.dart';
import '../../domain/saved_places.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  const LocationDetailScreen({super.key});

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen> {
  bool _loading = true;
  String? _error;
  Position? _pos;
  String? _city;
  String? _address;
  WeatherData? _weather;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _pos = pos;

      // Reverse geocode (best-effort) + weather in parallel.
      final results = await Future.wait([
        _reverseGeocode(pos.latitude, pos.longitude),
        WeatherService().fetch(pos.latitude, pos.longitude),
      ]);
      _weather = results[1] as WeatherData;
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'location-failed';
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final m = marks.first;
        _city = [m.locality, m.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toSet()
            .join(', ');
        _address = [
          m.street,
          m.subLocality,
          m.locality,
          m.postalCode,
          m.administrativeArea,
          m.country,
        ].where((s) => s != null && s.isNotEmpty).cast<String>().join(', ');
      }
    } catch (_) {/* geocoding optional */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('Current Location', 'Güncel Konum')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _content(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              L.t('Could not get your location. Check location permission and try again.',
                  'Konumun alınamadı. Konum iznini kontrol edip tekrar dene.'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: Text(L.t('Retry', 'Tekrar dene'))),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final w = _weather;
    final desc = describeWeather(w?.weatherCode);
    final aqi = describeAqi(w?.europeanAqi);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // City + condition hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandNavyLight, AppColors.surfaceCard],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Text(desc.icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _city?.isNotEmpty == true
                          ? _city!
                          : L.t('Your location', 'Konumun'),
                      style: AppTextStyles.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(L.isTr ? desc.tr : desc.en,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (w?.tempC != null)
                Text('${w!.tempC!.round()}°',
                    style: AppTextStyles.displayMedium
                        .copyWith(color: AppColors.brandTeal)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Weather metrics grid
        Text(L.t('Weather now', 'Şu anki hava'),
            style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _metric(Icons.water_drop_outlined, L.t('Rain', 'Yağmur'),
                w?.precipMm != null ? '${w!.precipMm!.toStringAsFixed(1)} mm' : '—'),
            _metric(Icons.air, L.t('Wind', 'Rüzgar'),
                w?.windKmh != null ? '${w!.windKmh!.round()} km/h' : '—'),
            _metric(Icons.opacity, L.t('Humidity', 'Nem'),
                w?.humidity != null ? '%${w!.humidity}' : '—'),
            _metric(Icons.wb_sunny_outlined, L.t('UV index', 'UV indeksi'),
                w?.uvIndex != null ? w!.uvIndex!.toStringAsFixed(1) : '—'),
            _metric(
                Icons.eco_outlined,
                L.t('Air quality', 'Hava kalitesi'),
                w?.europeanAqi != null
                    ? '${w!.europeanAqi} · ${L.isTr ? aqi.tr : aqi.en}'
                    : '—'),
            _metric(Icons.blur_on, 'PM2.5',
                w?.pm25 != null ? '${w!.pm25!.round()} µg/m³' : '—'),
          ],
        ),
        const SizedBox(height: 16),

        // Exact location + coordinates
        Text(L.t('Exact location', 'Tam konum'),
            style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_address?.isNotEmpty == true) ...[
                Text(_address!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.my_location,
                      size: 18, color: AppColors.brandTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pos != null
                          ? '${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}'
                          : '—',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: L.t('Copy', 'Kopyala'),
                    onPressed: _pos == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(
                                text:
                                    '${_pos!.latitude},${_pos!.longitude}'));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(L.t('Coordinates copied',
                                    'Koordinatlar kopyalandı'))));
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _pos == null ? null : _openInMaps,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(L.t('Open in Maps', 'Haritada aç')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _pos == null ? null : _savePlace,
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: Text(L.t('Save place', 'Konumu kaydet')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          L.t('Saved spots live in Profile › Saved places — return to them years later.',
              'Kaydettiğin yerler Profil › Kayıtlı yerlerim\'de durur — yıllar sonra bile aynı noktaya dön.'),
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.brandTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps() async {
    if (_pos != null) {
      await _openCoordsInMaps(_pos!.latitude, _pos!.longitude, _city ?? 'Pin');
    }
  }

  Future<void> _openCoordsInMaps(double lat, double lng, String label) async {
    final uri = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=${Uri.encodeComponent(label)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // One-tap save: the spot is persisted immediately with a sensible default
  // name (the detected city, else its coordinates) and shows up under
  // Profile › Saved places, where it can be renamed or deleted.
  Future<void> _savePlace() async {
    if (_pos == null) return;
    final now = DateTime.now();
    final defaultName = (_city != null && _city!.isNotEmpty)
        ? _city!
        : '${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)}';
    await ref.read(savedPlacesProvider.notifier).add(SavedPlace(
          id: now.millisecondsSinceEpoch.toString(),
          name: defaultName,
          lat: _pos!.latitude,
          lng: _pos!.longitude,
          city: _city,
          address: _address,
          savedAt: now,
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('Saved to Profile › Saved places',
              'Profil › Kayıtlı yerlerim\'e kaydedildi'))));
    }
  }
}
