# QuakeScope (DEPREM İZLEME IOS MOBİL UYGULAMASI)

Türkiye ve yakın çevrede gerçekleşen depremleri anlık izleyen, harita üzerinde gösteren ve eşik değerlerine göre bildirim gönderebilen iOS uygulaması.

SwiftUI • MapKit • async/await • MVVM • Background Tasks • UserNotifications

# Özellikler

Canlı veri akışı: AFAD /  Kandilli kaynaklı deprem listesi / USGS

Harita görünümü: Depremleri pin veya cluster olarak gösterme, yakınlaştırma

Filtreleme & sıralama: Büyüklük (Mw), tarih, bölge filtreleri

Bildirimler: Belirlediğin eşiğin üzerindeki depremlerde yerel bildirim

Arkaplan yenileme: Belirli aralıklarla veriyi yenileme (BGAppRefreshTask)

Konum farkındalığı: Kullanıcının konumuna göre yakın depremleri vurgulama

Karanlık mod: iOS sistem temasıyla uyumlu koyu/açık görünüm

Tamamen yerel ayarlar: Eşik, bölge, filtreler cihazda saklanır
