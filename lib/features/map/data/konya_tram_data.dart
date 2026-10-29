import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../domain/transit_models.dart';

abstract class KonyaTramData {
  /// Line T1: Alaaddin – Selçuk Üniversitesi / Kampüs (Campus Line)
  static const TramLine lineT1 = TramLine(
    id: 'tram-t1',
    code: 'T1',
    name: 'Alaaddin - Selçuk Üniversitesi / Kampüs',
    color: Color(0xFFD32F2F), // Red branding for Line T1
    stops: [
      TramStop(
        id: 't1-alaaddin',
        name: 'Alaaddin',
        lineCode: 'T1',
        location: LatLng(37.8722, 32.4931),
        sequenceIndex: 1,
      ),
      TramStop(
        id: 't1-zafer',
        name: 'Zafer',
        lineCode: 'T1',
        location: LatLng(37.8710, 32.4890),
        sequenceIndex: 2,
      ),
      TramStop(
        id: 't1-kulturpark',
        name: 'Kültürpark',
        lineCode: 'T1',
        location: LatLng(37.8739, 32.4883),
        sequenceIndex: 3,
      ),
      TramStop(
        id: 't1-belediye',
        name: 'Belediye',
        lineCode: 'T1',
        location: LatLng(37.8770, 32.4885),
        sequenceIndex: 4,
      ),
      TramStop(
        id: 't1-nalcaci',
        name: 'Nalçacı',
        lineCode: 'T1',
        location: LatLng(37.8830, 32.4880),
        sequenceIndex: 5,
      ),
      TramStop(
        id: 't1-kule',
        name: 'Kule',
        lineCode: 'T1',
        location: LatLng(37.8920, 32.4895),
        sequenceIndex: 6,
      ),
      TramStop(
        id: 't1-kunduracilar',
        name: 'Kunduracılar',
        lineCode: 'T1',
        location: LatLng(37.9000, 32.4910),
        sequenceIndex: 7,
      ),
      TramStop(
        id: 't1-eski-sanayi',
        name: 'Eski Sanayi',
        lineCode: 'T1',
        location: LatLng(37.9070, 32.4930),
        sequenceIndex: 8,
      ),
      TramStop(
        id: 't1-aydinlikevler',
        name: 'Aydınlıkevler',
        lineCode: 'T1',
        location: LatLng(37.9150, 32.4960),
        sequenceIndex: 9,
      ),
      TramStop(
        id: 't1-sehitler-camii',
        name: 'Şehitler Camii',
        lineCode: 'T1',
        location: LatLng(37.9220, 32.4980),
        sequenceIndex: 10,
      ),
      TramStop(
        id: 't1-teknik-lise',
        name: 'Teknik Lise',
        lineCode: 'T1',
        location: LatLng(37.9290, 32.5000),
        sequenceIndex: 11,
      ),
      TramStop(
        id: 't1-organize-sanayi',
        name: '1. Organize Sanayi',
        lineCode: 'T1',
        location: LatLng(37.9360, 32.5030),
        sequenceIndex: 12,
      ),
      TramStop(
        id: 't1-eyup-sultan',
        name: 'Eyüp Sultan',
        lineCode: 'T1',
        location: LatLng(37.9420, 32.5050),
        sequenceIndex: 13,
      ),
      TramStop(
        id: 't1-binkonutlar',
        name: 'Binkonutlar',
        lineCode: 'T1',
        location: LatLng(37.9470, 32.5080),
        sequenceIndex: 14,
      ),
      TramStop(
        id: 't1-erenkaya-caddesi',
        name: 'Erenkaya Caddesi',
        lineCode: 'T1',
        location: LatLng(37.9500, 32.5095),
        sequenceIndex: 15,
      ),
      TramStop(
        id: 't1-otogar',
        name: 'Otogar (Bus Terminal)',
        lineCode: 'T1',
        location: LatLng(37.9519, 32.5111),
        sequenceIndex: 16,
      ),
      TramStop(
        id: 't1-medas',
        name: 'MEDAŞ',
        lineCode: 'T1',
        location: LatLng(37.9535, 32.5090),
        sequenceIndex: 17,
      ),
      TramStop(
        id: 't1-elmalili-hamdi',
        name: 'Elmalılı Hamdi',
        lineCode: 'T1',
        location: LatLng(37.9540, 32.5080),
        sequenceIndex: 18,
      ),
      TramStop(
        id: 't1-mta',
        name: 'M.T.A.',
        lineCode: 'T1',
        location: LatLng(37.9541, 32.5075),
        sequenceIndex: 19,
      ),
      TramStop(
        id: 't1-yazir',
        name: 'Yazır',
        lineCode: 'T1',
        location: LatLng(37.95415, 32.5073),
        sequenceIndex: 20,
      ),
      TramStop(
        id: 't1-japon-parki',
        name: 'Japon Parkı',
        lineCode: 'T1',
        location: LatLng(37.9542, 32.5072),
        sequenceIndex: 21,
      ),
      TramStop(
        id: 't1-sancak',
        name: 'Sancak',
        lineCode: 'T1',
        location: LatLng(37.9600, 32.5120),
        sequenceIndex: 22,
      ),
      TramStop(
        id: 't1-piri-reis',
        name: 'Piri Reis',
        lineCode: 'T1',
        location: LatLng(37.9650, 32.5150),
        sequenceIndex: 23,
      ),
      TramStop(
        id: 't1-firat-caddesi',
        name: 'Fırat Caddesi',
        lineCode: 'T1',
        location: LatLng(37.9710, 32.5180),
        sequenceIndex: 24,
      ),
      TramStop(
        id: 't1-buzlukbasi-koprusu',
        name: 'Buzlukbaşı Köprüsü',
        lineCode: 'T1',
        location: LatLng(37.9760, 32.5200),
        sequenceIndex: 25,
      ),
      TramStop(
        id: 't1-bosna-hersek',
        name: 'Bosna Hersek',
        lineCode: 'T1',
        location: LatLng(37.9800, 32.5220),
        sequenceIndex: 26,
      ),
      TramStop(
        id: 't1-kayalar-camii',
        name: 'Kayalar Camii',
        lineCode: 'T1',
        location: LatLng(37.9830, 32.5235),
        sequenceIndex: 27,
      ),
      TramStop(
        id: 't1-kampus-hareket',
        name: 'Kampüs Hareket (Selçuk Üniv.)',
        lineCode: 'T1',
        location: LatLng(37.9850, 32.5250),
        sequenceIndex: 28,
      ),
      TramStop(
        id: 't1-tip-fakultesi',
        name: 'Tıp Fakültesi',
        lineCode: 'T1',
        location: LatLng(37.9870, 32.5265),
        sequenceIndex: 29,
      ),
      TramStop(
        id: 't1-hukuk-fakultesi',
        name: 'Hukuk Fakültesi',
        lineCode: 'T1',
        location: LatLng(37.9890, 32.5280),
        sequenceIndex: 30,
      ),
      TramStop(
        id: 't1-fen-edebiyat',
        name: 'Fen Edebiyat Fakültesi',
        lineCode: 'T1',
        location: LatLng(37.9910, 32.5295),
        sequenceIndex: 31,
      ),
      TramStop(
        id: 't1-muhendislik',
        name: 'Mühendislik Fakültesi',
        lineCode: 'T1',
        location: LatLng(37.9930, 32.5310),
        sequenceIndex: 32,
      ),
    ],
  );

  /// Line T2: Alaaddin – Şehir Hastanesi (Courthouse & City Hospital Line)
  static const TramLine lineT2 = TramLine(
    id: 'tram-t2',
    code: 'T2',
    name: 'Alaaddin - Şehir Hastanesi',
    color: Color(0xFF1976D2), // Blue branding for Line T2
    stops: [
      TramStop(
        id: 't2-alaaddin',
        name: 'Alaaddin',
        lineCode: 'T2',
        location: LatLng(37.8722, 32.4931),
        sequenceIndex: 1,
      ),
      TramStop(
        id: 't2-zafer',
        name: 'Zafer',
        lineCode: 'T2',
        location: LatLng(37.8710, 32.4890),
        sequenceIndex: 2,
      ),
      TramStop(
        id: 't2-hukumet',
        name: 'Hükümet Meydanı',
        lineCode: 'T2',
        location: LatLng(37.8705, 32.4980),
        sequenceIndex: 3,
      ),
      TramStop(
        id: 't2-mevlana',
        name: 'Mevlana',
        lineCode: 'T2',
        location: LatLng(37.8703, 32.5042),
        sequenceIndex: 4,
      ),
      TramStop(
        id: 't2-mevlana-kultur',
        name: 'Mevlana Kültür Merkezi',
        lineCode: 'T2',
        location: LatLng(37.8690, 32.5100),
        sequenceIndex: 5,
      ),
      TramStop(
        id: 't2-fetih-caddesi',
        name: 'Fetih Caddesi',
        lineCode: 'T2',
        location: LatLng(37.8682, 32.5180),
        sequenceIndex: 6,
      ),
      TramStop(
        id: 't2-spor-kongre',
        name: 'Spor ve Kongre Merkezi',
        lineCode: 'T2',
        location: LatLng(37.8665, 32.5270),
        sequenceIndex: 7,
      ),
      TramStop(
        id: 't2-karsehir-caddesi',
        name: 'Karşehir Caddesi',
        lineCode: 'T2',
        location: LatLng(37.8655, 32.5310),
        sequenceIndex: 8,
      ),
      TramStop(
        id: 't2-adliye',
        name: 'Adliye (Courthouse)',
        lineCode: 'T2',
        location: LatLng(37.8650, 32.5350),
        sequenceIndex: 9,
      ),
      TramStop(
        id: 't2-sehir-hastanesi',
        name: 'Şehir Hastanesi (City Hospital)',
        lineCode: 'T2',
        location: LatLng(37.8630, 32.5450),
        sequenceIndex: 10,
      ),
    ],
  );

  static const List<TramLine> allLines = [lineT1, lineT2];

  static List<TramStop> get allStops {
    final List<TramStop> stops = [];
    for (final line in allLines) {
      stops.addAll(line.stops);
    }
    return stops;
  }
}
