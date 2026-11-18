@extends('legal.layout')

@section('title', 'Kebijakan Privasi (Privacy Policy)')
@section('meta_description', 'Kebijakan Privasi data pengguna aplikasi Phonebook CDK Wilayah V Garut, pelaporan kehutanan, dan bot Discord.')

@section('badge_text', 'Kebijakan Privasi Resmi')
@section('page_heading', 'Kebijakan Privasi')
@section('page_subheading', 'Komitmen perlindungan data pribadi pengguna aplikasi Phonebook, dokumentasi kehutanan, dan integrasi bot Discord.')

@section('content')
<div class="legal-content">

    <!-- Table of Contents -->
    <div class="toc-card">
        <div class="toc-title">Daftar Isi Kebijakan Privasi</div>
        <ul class="toc-list">
            <li><a href="#komitmen" class="toc-link">1. Komitmen Privasi</a></li>
            <li><a href="#data-dikumpulkan" class="toc-link">2. Data yang Kami Kumpulkan</a></li>
            <li><a href="#tujuan-penggunaan" class="toc-link">3. Tujuan Penggunaan Data</a></li>
            <li><a href="#discord-bot-data" class="toc-link">4. Privasi Integrasi Bot Discord</a></li>
            <li><a href="#whatsapp-fonnte" class="toc-link">5. Komunikasi WhatsApp (Fonnte)</a></li>
            <li><a href="#penyimpanan-keamanan" class="toc-link">6. Keamanan & Penyimpanan Data</a></li>
            <li><a href="#pembagian-pihak-ketiga" class="toc-link">7. Keterlibatan Pihak Ketiga</a></li>
            <li><a href="#hak-pengguna" class="toc-link">8. Hak & Akses Pengguna</a></li>
            <li><a href="#retensi-penghapusan" class="toc-link">9. Retensi & Penghapusan Data</a></li>
            <li><a href="#kontak-dpo" class="toc-link">10. Kontak Perlindungan Data</a></li>
        </ul>
    </div>

    <!-- 1. Komitmen Privasi -->
    <h2 id="komitmen">
        <span class="section-number">1</span>
        Komitmen Privasi
    </h2>
    <p>
        <strong>Cabang Dinas Kehutanan (CDK) Wilayah V Garut</strong> ("kami") mengelola aplikasi <strong>Phonebook</strong> dengan prinsip penghormatan tinggi terhadap privasi data pribadi aparatur, penyuluh kehutanan, tenaga teknis, serta pengguna layanan. Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, menyimpan, dan melindungi informasi pribadi Anda saat menggunakan aplikasi mobile Phonebook, layanan backend API, bot Discord developer, dan sistem integrasi terkait.
    </p>

    <!-- 2. Data yang Kami Kumpulkan -->
    <h2 id="data-dikumpulkan">
        <span class="section-number">2</span>
        Informasi yang Kami Kumpulkan
    </h2>
    <p>
        Untuk menunjang operasional kedinasan dan pelaporan kegiatan, sistem kami memproses jenis data berikut:
    </p>
    <ul>
        <li><strong>Informasi Profil & Akun:</strong> Nama lengkap, alamat email resmi, jabatan, unit kerja, foto profil (dari akun Google jika menggunakan SSO Google), dan nomor WhatsApp aktif.</li>
        <li><strong>Data Laporan Kegiatan Lapangan:</strong> Judul kegiatan, kategori kegiatan kehutanan, tanggal pelaksanaan, deskripsi rinci, jumlah peserta/anggota masyarakat yang didampingi, serta lokasi koordinat geografis jika disematkan.</li>
        <li><strong>Foto Dokumentasi Lapangan:</strong> Foto-foto dokumentasi kegiatan yang diunggah melalui kamera perangkat atau galeri ponsel, disimpan beserta metadata resolusi dan rasio aspek.</li>
        <li><strong>Data Laporan Masalah & Tiket Pengaduan:</strong> Judul kendala teknis, kategori bug, deskripsi masalah, nomor WhatsApp kontak darurat pelapor, kode tiket unik (misal: <code>TKT-202611...</code>), dan tanggapan/solusi pengembang.</li>
        <li><strong>Data Teknis Perangkat & Sesi:</strong> Model perangkat, versi sistem operasi (Android / iOS), alamat IP jaringan, status otentikasi sesi token, serta data cache luring yang tersimpan aman di database lokal SQLite perangkat.</li>
    </ul>

    <!-- 3. Tujuan Penggunaan Data -->
    <h2 id="tujuan-penggunaan">
        <span class="section-number">3</span>
        Tujuan Penggunaan Informasi
    </h2>
    <p>
        Data yang dikumpulkan dipergunakan semata-mata untuk kepentingan kedinasan dan keandalan sistem:
    </p>
    <ul>
        <li>Memverifikasi identitas pengguna dan memberikan hak akses sesuai jabatan atau unit kerja.</li>
        <li>Menyusun laporan kinerja kegiatan lapangan resmi yang dapat diekspor menjadi format dokumen cetak resmi instansi.</li>
        <li>Melakukan sinkronisasi data dua arah antara penyimpanan lokal offline (SQLite) dengan cloud database server saat sinyal internet tersedia.</li>
        <li>Menangani kendala operasional atau bug aplikasi yang dilaporkan pengguna secara langsung kepada tim developer.</li>
    </ul>

    <!-- 4. Privasi Integrasi Bot Discord -->
    <h2 id="discord-bot-data">
        <span class="section-number">4</span>
        Privasi Integrasi Bot Discord Pengembang
    </h2>
    <div class="callout-box">
        <div class="callout-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
            </svg>
            Kepatuhan Privasi Discord API (Discord Privacy Policy Compliance)
        </div>
        Bot Discord Phonebook hanya beroperasi di server internal pengembang yang telah ditentukan dan dibatasi aksesnya hanya untuk administrator dan tim pemeliharaan sistem resmi CDK Wilayah V Garut.
    </div>
    <p>
        Terkait interaksi bot Discord:
    </p>
    <ul>
        <li><strong>Informasi yang Diteruskan:</strong> Ketika pengguna mengirim "Laporkan Masalah", hanya ringkasan masalah (nama pelapor, email, nomor WhatsApp untuk konfirmasi tindak lanjut, judul bug, dan deskripsi) yang dikirimkan ke kanal Discord pengembang.</li>
        <li><strong>Aksi Penyelesaian:</strong> Saat pengembang menekan tombol interaktif Discord (ACC / Tolak / Selesai) dan mengisi alasan penyelesaian, catatan tersebut dicatat ke database cloud Supabase dan dikirimkan kembali ke pengguna sebagai status penanganan resmi.</li>
        <li><strong>Batas Akses Data:</strong> Bot Discord Phonebook <em>tidak</em> membaca riwayat obrolan pribadi pengguna di Discord, <em>tidak</em> mengumpulkan daftar anggota server di luar kebutuhan operasional, dan <em>tidak</em> menyimpan pesan Discord di luar konteks tiket pengaduan Phonebook.</li>
    </ul>

    <!-- 5. Komunikasi WhatsApp (Fonnte) -->
    <h2 id="whatsapp-fonnte">
        <span class="section-number">5</span>
        Komunikasi Melalui WhatsApp Gateway (Fonnte)
    </h2>
    <p>
        Aplikasi Phonebook mengintegrasikan gateway WhatsApp resmi pihak ketiga (Fonnte API) untuk pengiriman notifikasi instan:
    </p>
    <ul>
        <li>Nomor WhatsApp hanya digunakan untuk mengirimkan notifikasi status tiket pengaduan (ketika tiket diterima, ditolak, atau selesai ditangani) dan pengingat jadwal tugas kehutanan.</li>
        <li>Nomor WhatsApp pengguna dijaga kerahasiaannya dan tidak dipublikasikan ke publik atau dibagikan ke pihak ketiga lainnya.</li>
        <li>Sistem tidak pernah mengirimkan pesan berantai, spam, atau promosi komersial.</li>
    </ul>

    <!-- 6. Keamanan & Penyimpanan Data -->
    <h2 id="penyimpanan-keamanan">
        <span class="section-number">6</span>
        Keamanan & Lokasi Penyimpanan Data
    </h2>
    <p>
        Kami menerapkan standar keamanan teknis berlapis guna melindungi integritas data Anda:
    </p>
    <ul>
        <li><strong>PostgreSQL Supabase (Enterprise Cloud):</strong> Seluruh data pengguna, jadwal, laporan kegiatan, dan tiket disimpan di infrastruktur cloud database PostgreSQL terkelola Supabase dengan enkripsi saat istirahat (<em>encryption-at-rest</em>) dan enkripsi saat transit (SSL/TLS).</li>
        <li><strong>Enkripsi Komunikasi:</strong> Seluruh pertukaran data antara aplikasi Flutter dan backend Laravel berjalan di atas protokol aman HTTPS dengan sertifikat TLS modern.</li>
        <li><strong>Kriptografi Ed25519:</strong> Seluruh permintaan webhook dan interaksi Discord divalidasi keabsahannya dengan kunci kriptografis publik Ed25519.</li>
        <li><strong>Keamanan Kredensial:</strong> Kata sandi di-hash menggunakan algoritma <code>bcrypt</code> modern berstandar industri. Bot token dan kunci API backend disimpan secara ketat di environment variable serverless yang terisolasi dan tidak pernah diekspos ke frontend.</li>
    </ul>

    <!-- 7. Keterlibatan Pihak Ketiga -->
    <h2 id="pembagian-pihak-ketiga">
        <span class="section-number">7</span>
        Pihak Ketiga & Pemrosesan Layanan
    </h2>
    <p>
        Data Anda tidak pernah dijual atau disewakan kepada pihak manapun. Sistem kami hanya berkomunikasi dengan penyedia infrastruktur terpercaya berikut:
    </p>
    <div class="table-responsive">
        <table>
            <thead>
                <tr>
                    <th>Layanan Pihak Ketiga</th>
                    <th>Peran & Kegunaan</th>
                    <th>Kebijakan Terkait</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td><strong>PostgreSQL Supabase</strong></td>
                    <td>Penyimpanan cloud database utama dan relasi berkas</td>
                    <td>Supabase Privacy & Security Standard</td>
                </tr>
                <tr>
                    <td><strong>Discord Inc.</strong></td>
                    <td>Kanal triase tiket laporan masalah bagi developer</td>
                    <td>Discord Developer Terms & Privacy</td>
                </tr>
                <tr>
                    <td><strong>Fonnte API</strong></td>
                    <td>Gateway pengiriman notifikasi status tiket ke WhatsApp</td>
                    <td>Fonnte API Service Agreement</td>
                </tr>
                <tr>
                    <td><strong>Google Identity Services</strong></td>
                    <td>Otentikasi aman Single Sign-On (Google OAuth)</td>
                    <td>Google OAuth 2.0 User Data Policy</td>
                </tr>
                <tr>
                    <td><strong>Vercel Cloud Platform</strong></td>
                    <td>Infrastruktur hosting komputasi serverless backend</td>
                    <td>Vercel Security & Privacy Policy</td>
                </tr>
            </tbody>
        </table>
    </div>

    <!-- 8. Hak & Akses Pengguna -->
    <h2 id="hak-pengguna">
        <span class="section-number">8</span>
        Hak & Akses Pengguna
    </h2>
    <p>
        Setiap pengguna memiliki hak penuh atas data pribadi mereka:
    </p>
    <ul>
        <li><strong>Hak Akses & Pembaruan:</strong> Anda dapat memeriksa dan memperbarui informasi nama, foto profil, dan nomor WhatsApp kapan saja melalui menu Pengaturan Profil di aplikasi Flutter.</li>
        <li><strong>Hak Ekspor Data:</strong> Pengguna berhak mengunduh seluruh arsip laporan kegiatan yang dibuat dalam format dokumen cetak resmi instansi.</li>
        <li><strong>Hak Koreksi & Penghapusan:</strong> Pengguna dapat mengajukan permohonan perbaikan data yang keliru atau penghapusan akun dinas melalui administrator sistem CDK Wilayah V Garut.</li>
    </ul>

    <!-- 9. Retensi & Penghapusan Data -->
    <h2 id="retensi-penghapusan">
        <span class="section-number">9</span>
        Retensi & Penghapusan Data
    </h2>
    <p>
        Data laporan kegiatan lapangan disimpan sesuai kebutuhan arsip kinerja aparatur pemerintah daerah. Jika akun dinas dinonaktifkan atau dihapus atas instruksi instansi, data otentikasi pribadi akan dihapus secara permanen dari server aktif, sedangkan arsip laporan kegiatan yang telah disetujui akan diarsipkan sesuai regulasi kearsipan instansi kehutanan.
    </p>

    <!-- 10. Kontak DPO -->
    <h2 id="kontak-dpo">
        <span class="section-number">10</span>
        Kontak Tim Perlindungan Data & Pengembang
    </h2>
    <p>
        Apabila Anda memiliki pertanyaan, saran, atau kekhawatiran terkait Kebijakan Privasi ini atau pemrosesan data pribadi Anda di lingkungan aplikasi Phonebook, hubungi kami melalui:
    </p>
    <div class="callout-box info">
        <div class="callout-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                <polyline points="22,6 12,13 2,6"/>
            </svg>
            Cabang Dinas Kehutanan Wilayah V Garut
        </div>
        <p style="margin: 6px 0 0 0;">
            Dinas Kehutanan Pemerintah Provinsi Jawa Barat<br>
            Jl. Raya Garut - Bayongbong Km. 3, Garut, Jawa Barat<br>
            Email Dukungan Privasi: <code>support@phonebook-five-umber.vercel.app</code> / <code>cdkwil5garut@gmail.com</code><br>
            Situs Web Layanan: <code>https://phonebook-five-umber.vercel.app</code>
        </p>
    </div>

</div>
@endsection
