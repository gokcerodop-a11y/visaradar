// weather_service.dart — live weather + air quality via Open-Meteo (free, no
// API key). Two public endpoints; failures degrade gracefully to null fields.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  const WeatherData({
    this.tempC,
    this.windKmh,
    this.humidity,
    this.precipMm,
    this.uvIndex,
    this.weatherCode,
    this.europeanAqi,
    this.pm25,
  });

  final double? tempC;
  final double? windKmh;
  final int? humidity; // %
  final double? precipMm;
  final double? uvIndex;
  final int? weatherCode; // WMO code
  final int? europeanAqi; // 0-20 good … 100+ very poor
  final double? pm25; // µg/m³
}

class WeatherService {
  final http.Client _client;
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherData> fetch(double lat, double lng) async {
    final weather = await _fetchForecast(lat, lng);
    final air = await _fetchAir(lat, lng);
    return WeatherData(
      tempC: weather['temperature_2m']?.toDouble(),
      windKmh: weather['wind_speed_10m']?.toDouble(),
      humidity: (weather['relative_humidity_2m'] as num?)?.round(),
      precipMm: weather['precipitation']?.toDouble(),
      uvIndex: weather['uv_index']?.toDouble(),
      weatherCode: (weather['weather_code'] as num?)?.toInt(),
      europeanAqi: (air['european_aqi'] as num?)?.round(),
      pm25: air['pm2_5']?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _fetchForecast(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,precipitation,'
        'weather_code,wind_speed_10m,uv_index&timezone=auto',
      );
      final r = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return {};
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (j['current'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('[WeatherService] forecast: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchAir(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lng&current=european_aqi,pm2_5',
      );
      final r = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return {};
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (j['current'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('[WeatherService] air: $e');
      return {};
    }
  }
}

/// Maps a WMO weather code to (englishDesc, turkishDesc, emoji).
({String en, String tr, String icon}) describeWeather(int? code) {
  switch (code) {
    case 0:
      return (en: 'Clear sky', tr: 'Açık', icon: '☀️');
    case 1:
    case 2:
      return (en: 'Partly cloudy', tr: 'Parçalı bulutlu', icon: '⛅');
    case 3:
      return (en: 'Overcast', tr: 'Kapalı', icon: '☁️');
    case 45:
    case 48:
      return (en: 'Fog', tr: 'Sisli', icon: '🌫️');
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return (en: 'Drizzle', tr: 'Çiseleme', icon: '🌦️');
    case 61:
    case 63:
    case 65:
    case 80:
    case 81:
    case 82:
      return (en: 'Rain', tr: 'Yağmurlu', icon: '🌧️');
    case 66:
    case 67:
      return (en: 'Freezing rain', tr: 'Dondurucu yağmur', icon: '🌧️');
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return (en: 'Snow', tr: 'Karlı', icon: '❄️');
    case 95:
    case 96:
    case 99:
      return (en: 'Thunderstorm', tr: 'Gök gürültülü fırtına', icon: '⛈️');
    default:
      return (en: '—', tr: '—', icon: '🌡️');
  }
}

/// Air-quality label from the European AQI value.
({String en, String tr}) describeAqi(int? aqi) {
  if (aqi == null) return (en: '—', tr: '—');
  if (aqi <= 20) return (en: 'Good', tr: 'İyi');
  if (aqi <= 40) return (en: 'Fair', tr: 'Orta');
  if (aqi <= 60) return (en: 'Moderate', tr: 'Hassas');
  if (aqi <= 80) return (en: 'Poor', tr: 'Kötü');
  if (aqi <= 100) return (en: 'Very poor', tr: 'Çok kötü');
  return (en: 'Extremely poor', tr: 'Aşırı kötü');
}
