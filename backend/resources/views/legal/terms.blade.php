@extends('legal.layout')

@section('title', 'Ketentuan Layanan (Terms of Service)')
@section('meta_description', 'Ketentuan Layanan aplikasi Phonebook CDK Wilayah V Garut dan integrasi bot Discord developer.')

@section('badge_text', 'Ketentuan Layanan Resmi')
@section('page_heading', 'Ketentuan Layanan')
@section('page_subheading', 'Syarat dan ketentuan penggunaan aplikasi Phonebook, sistem pelaporan kegiatan kehutanan, dan integrasi bot Discord.')

@section('content')
<div class="legal-content">

    <!-- Table of Contents -->
    <div class="toc-card">
        <div class="toc-title">Daftar Isi Ketentuan</div>
        <ul class="toc-list">
            <li><a href="#pendahuluan" class="toc-link">1. Pendahuluan & Persetujuan</a></li>
            <li><a href="#lingkup-layanan" class="toc-link">2. Ruang Lingkup Layanan</a></li>
            <li><a href="#akun-otentikasi" class="toc-link">3. Akun & Keamanan Pengguna</a></li>
            <li><a href="#discord-bot" class="toc-link">4. Integrasi Bot & Tiket Discord</a></li>
            <li><a href="#pelaporan-kegiatan" class="toc-link">5. Pelaporan & Unggahan Berkas</a></li>
            <li><a href="#notifikasi-whatsapp" class="toc-link">6. Notifikasi Otomatis WhatsApp</a></li>
            <li><a href="#hak-kekayaan-intelektual" class="toc-link">7. Hak Kekayaan Intelektual</a></li>
            <li><a href="#batasan-tanggung-jawab" class="toc-link">8. Batasan Tanggung Jawab</a></li>
            <li><a href="#perubahan-ketentuan" class="toc-link">9. Perubahan Ketentuan</a></li>
            <li><a href="#hukum-kontak" class="toc-link">10. Hukum & Kontak Pengembang</a></li>
        </ul>
    </div>

    <!-- 1. Pendahuluan -->
    <h2 id="pendahuluan">
        <span class="section-number">1</span>
        Pendahuluan & Persetujuan Ketentuan
    </h2>
    <p>
        Selamat datang di <strong>Phonebook</strong>, aplikasi direktori kerja dan sistem pelaporan kegiatan kehutanan resmi untuk lingkungan <strong>Cabang Dinas Kehutanan (CDK) Wilayah V Garut</strong>, Dinas Kehutanan Pemerintah Daerah Provinsi Jawa Barat.
    </p>
    <p>
        Dengan mengunduh, memasang, mendaftarkan akun, mengakses platform mobile, atau berinteraksi dengan layanan terkait (termasuk <strong>Phonebook Discord Developer Bot</strong> dan antarmuka web), Anda menyatakan telah membaca, memahami, dan menyetujui untuk terikat oleh Ketentuan Layanan ini. Jika Anda tidak menyetujui ketentuan ini, Anda tidak diperkenankan menggunakan aplikasi dan layanannya.
    </p>

    <!-- 2. Ruang Lingkup Layanan -->
    <h2 id="lingkup-layanan">
        <span class="section-number">2</span>
        Ruang Lingkup Layanan
    </h2>
    <p>
        Aplikasi Phonebook menyediakan fungsionalitas pendukung operasional aparatur dan mitra kehutanan, yang mencakup:
    </p>
    <ul>
        <li><strong>Direktori Kontak Kepegawaian:</strong> Akses nomor kontak resmi, unit kerja, dan jabatan staf CDK Wilayah V Garut.</li>
        <li><strong>Sistem Pelaporan Kegiatan Lapangan:</strong> Pencatatan kegiatan pendampingan masyarakat, penyuluhan, inventarisasi hutan, penanaman, serta dokumentasi visual kegiatan.</li>
        <li><strong>Manajemen Template Laporan:</strong> Pengambilan dan caching template laporan baik secara daring maupun luring (offline cache SQLite).</li>
        <li><strong>Penyimpanan Materi & Regulasi:</strong> Pengunduhan dan pembacaan materi teknis kehutanan dan pedoman SOP.</li>
        <li><strong>Pusat Pengaduan & Laporan Masalah:</strong> Penyampaian kendala teknis dan bug sistem yang terhubung langsung ke saluran pengembang.</li>
    </ul>

    <!-- 3. Akun & Keamanan Pengguna -->
    <h2 id="akun-otentikasi">
        <span class="section-number">3</span>
        Akun, Otentikasi, & Tanggung Jawab Pengguna
    </h2>
    <p>
        Pengguna bertanggung jawab penuh atas keamanan dan kerahasiaan kredensial akun mereka:
    </p>
    <ul>
        <li>Otentikasi dapat dilakukan melalui alamat email kedinasan terdaftar atau melalui Single Sign-On (Google Authentication).</li>
        <li>Pengguna wajib memberikan nomor WhatsApp aktif dan data identitas yang akurat untuk keperluan verifikasi dan pengiriman pemberitahuan resmi.</li>
        <li>Dilarang keras menyalahgunakan akun pihak lain, membagikan token otentikasi (JWT / Sanctum Token), atau melakukan rekayasa sistem yang merugikan integritas database.</li>
    </ul>

    <!-- 4. Integrasi Bot & Tiket Discord -->
    <h2 id="discord-bot">
        <span class="section-number">4</span>
        Integrasi Bot Discord & Sistem Tiket Pengaduan
    </h2>
    <div class="callout-box">
        <div class="callout-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
            </svg>
            Kepatuhan Pengembang Discord (Discord Developer Terms of Service)
        </div>
        Layanan ini mengintegrasikan aplikasi bot Discord (<strong>Phonebook Bot</strong>) sebagai sarana triase tiket teknis internal pengembang. Bot beroperasi di bawah kepatuhan penuh terhadap Kebijakan Pengembang Discord.
    </div>
    <p>
        Ketentuan operasional bot Discord mencakup:
    </p>
    <ul>
        <li><strong>Penerusan Laporan:</strong> Ketika pengguna mengirimkan "Laporan Masalah" melalui aplikasi, sistem secara otomatis meneruskan ringkasan tiket ke saluran khusus Discord pengembang dalam format embed hijau (forest green).</li>
        <li><strong>Aksi Interaktif Pengembang:</strong> Pengembang yang berwenang dapat merespons tiket melalui tombol Discord (<em>ACC Laporan</em>, <em>Tolak Laporan</em>, dan <em>Selesai Diproses</em>) dengan menyertakan catatan penyelesaian melalui dialog interaktif modal Discord.</li>
        <li><strong>Verifikasi Kriptografis:</strong> Seluruh permintaan interaksi Discord diverifikasi keasliannya menggunakan algoritma Ed25519 sesuai spesifikasi keamanan Discord API. Interaksi dengan tanda tangan digital tidak valid akan ditolak otomatis dengan kode HTTP 401.</li>
        <li><strong>Larangan Penyalahgunaan:</strong> Dilarang melakukan flood request, bot spoofing, atau memanipulasi parameter webhook untuk tujuan yang merusak.</li>
    </ul>

    <!-- 5. Pelaporan & Unggahan Berkas -->
    <h2 id="pelaporan-kegiatan">
        <span class="section-number">5</span>
        Pelaporan Kegiatan, Foto Dokumentasi, & Hak Akses
    </h2>
    <p>
        Dalam pengiriman laporan kegiatan lapangan:
    </p>
    <ul>
        <li>Foto yang dilampirkan harus berupa dokumentasi faktual kegiatan lapangan kehutanan, bukan gambar rekayasa, pornografi, ujaran kebencian, atau konten yang melanggar hukum perundang-undangan.</li>
        <li>Sistem menyimpan metadata foto, rasio aspek, ukuran file, dan path berkas ke dalam database cloud PostgreSQL Supabase secara terenkripsi.</li>
        <li>Aplikasi menyediakan opsi ekspor dokumen laporan (PDF / dokumen resmi) yang memuat foto dokumentasi kegiatan untuk keperluan pelaporan instansi.</li>
    </ul>

    <!-- 6. Notifikasi Otomatis WhatsApp -->
    <h2 id="notifikasi-whatsapp">
        <span class="section-number">6</span>
        Notifikasi Otomatis WhatsApp (Fonnte Gateway)
    </h2>
    <p>
        Pengguna menyetujui penerimaan pesan notifikasi otomatis melalui nomor WhatsApp yang didaftarkan. Notifikasi ini dikirimkan melalui gateway Fonnte resmi hanya untuk keperluan:
    </p>
    <ul>
        <li>Pembaruan status tiket laporan masalah (Disetujui, Ditolak, atau Selesai Ditangani beserta solusi/keterangan pengembang).</li>
        <li>Pengingat jadwal kegiatan lapangan dan agenda dinas penting.</li>
        <li>Sistem tidak akan mengirimkan pesan promosi, iklan pihak ketiga, atau spam pemasaran.</li>
    </ul>

    <!-- 7. Hak Kekayaan Intelektual -->
    <h2 id="hak-kekayaan-intelektual">
        <span class="section-number">7</span>
        Hak Kekayaan Intelektual
    </h2>
    <p>
        Seluruh hak cipta, merek dagang, logo, desain antarmuka aplikasi, kode program sumber (Flutter & Laravel), modul bot, dan dokumentasi Phonebook merupakan hak milik sah dari Cabang Dinas Kehutanan Wilayah V Garut dan Tim Pengembang Resmi Phonebook. Dilarang menggandakan, mendistribusikan ulang, atau merekayasa balik tanpa persetujuan tertulis.
    </p>

    <!-- 8. Batasan Tanggung Jawab -->
    <h2 id="batasan-tanggung-jawab">
        <span class="section-number">8</span>
        Batasan Tanggung Jawab
    </h2>
    <p>
        Layanan Phonebook disediakan atas dasar "sebagaimana adanya" (<em>as is</em>) dan "sebagaimana tersedia" (<em>as available</em>):
    </p>
    <ul>
        <li>Pengembang dan CDK Wilayah V berupaya maksimal menjaga ketersediaan layanan 24/7, namun tidak bertanggung jawab atas keterlambatan sinkronisasi yang diakibatkan oleh ketiadaan sinyal internet di kawasan hutan terpencil (area blank spot).</li>
        <li>Pengembang telah menyediakan fitur penyimpanan luring (offline cache) untuk memitigasi kendala konektivitas tersebut.</li>
    </ul>

    <!-- 9. Perubahan Ketentuan -->
    <h2 id="perubahan-ketentuan">
        <span class="section-number">9</span>
        Pembaruan Ketentuan Layanan
    </h2>
    <p>
        Kami berhak mengubah atau memperbarui Ketentuan Layanan ini sewaktu-waktu. Perubahan substansial akan diinformasikan melalui notifikasi dalam aplikasi atau pengumuman resmi. Melanjutkan penggunaan aplikasi setelah pembaruan menandakan persetujuan Anda atas ketentuan yang baru.
    </p>

    <!-- 10. Hukum & Kontak -->
    <h2 id="hukum-kontak">
        <span class="section-number">10</span>
        Hukum yang Berlaku & Kontak Pengembang
    </h2>
    <p>
        Ketentuan Layanan ini diatur dan ditafsirkan berdasarkan hukum Negara Kesatuan Republik Indonesia. Jika Anda memiliki pertanyaan mengenai Ketentuan Layanan ini atau operasional sistem, silakan menghubungi:
    </p>
    <div class="callout-box info">
        <div class="callout-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="2" y="4" width="20" height="16" rx="2"/>
                <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>
            </svg>
            Saluran Bantuan & Dukungan Teknis
        </div>
        <p style="margin: 6px 0 0 0;">
            <strong>Cabang Dinas Kehutanan Wilayah V Garut</strong><br>
            Dinas Kehutanan Provinsi Jawa Barat<br>
            Email Dukungan: <code>support@phonebook-five-umber.vercel.app</code> / <code>cdkwil5garut@gmail.com</code><br>
            Kanal Pengembang Discord: <code>#phonebook-dev-ticket</code> (Channel ID: <code>1572092848747192350</code>)
        </p>
    </div>

</div>
@endsection
