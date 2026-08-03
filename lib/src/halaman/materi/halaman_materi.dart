import 'package:flutter/material.dart';

class HalamanMateriEdukasi extends StatefulWidget {
  const HalamanMateriEdukasi({super.key});

  @override
  State<HalamanMateriEdukasi> createState() => _HalamanMateriEdukasiState();
}

class _HalamanMateriEdukasiState extends State<HalamanMateriEdukasi> {
  // State untuk melacak kategori mana yang sedang dipilih
  String _kategoriAktif = 'Semua';

  // Daftar kategori disesuaikan dengan permintaanmu (termasuk KTH, RHL, dll)
  final List<String> _daftarKategori = [
    'Semua',
    'KTH',
    'RHL',
    'Panduan',
    'Modul',
    'Jurnal'
  ];

  // Data materi agar filternya berfungsi saat diklik
  final List<Map<String, dynamic>> _semuaMateri = [
    {
      'judul': 'Panduan Budidaya Kopi Di Bawah Tegakan',
      'penulis': 'Dinas Kehutanan',
      'kategori': 'Panduan',
      'tipe': 'PDF',
      'ukuran': '2.4 MB',
      'warna': const Color(0xFFE53935), // Merah
    },
    {
      'judul': 'Modul Pencegahan Kebakaran Hutan 2026',
      'penulis': 'KLHK Pusat',
      'kategori': 'Modul',
      'tipe': 'DOCX',
      'ukuran': '1.1 MB',
      'warna': const Color(0xFF1E88E5), // Biru
    },
    {
      'judul': 'Teknik Pemetaan Partisipatif KTH',
      'penulis': 'Budi Santoso',
      'kategori': 'KTH',
      'tipe': 'PDF',
      'ukuran': '3.8 MB',
      'warna': const Color(0xFFE53935), // Merah
    },
    {
      'judul': 'Pedoman Pelaksanaan RHL Terpadu',
      'penulis': 'Dirjen PDASRH',
      'kategori': 'RHL',
      'tipe': 'PDF',
      'ukuran': '4.5 MB',
      'warna': const Color(0xFFE53935), // Merah
    },
    {
      'judul': 'Jurnal Pengelolaan Hutan Produksi',
      'penulis': 'Universitas Rimbawan',
      'kategori': 'Jurnal',
      'tipe': 'DOCX',
      'ukuran': '1.8 MB',
      'warna': const Color(0xFF1E88E5), // Biru
    },
  ];

  void _showFormUpload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Upload Materi Baru',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bagikan modul atau panduan untuk membantu pengguna lain.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Judul Materi',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Kategori (cth: KTH, Panduan, Jurnal)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Pilih File PDF/Word'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logika Filter: Menyaring materi berdasarkan kategori yang dipilih
    List<Map<String, dynamic>> materiDitampilkan = _semuaMateri.where((materi) {
      if (_kategoriAktif == 'Semua') return true;
      return materi['kategori'] == _kategoriAktif;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Latar belakang modern
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          physics: const BouncingScrollPhysics(),
          children: [
            const Text(
              'Materi Edukasi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Banner Informasi Mewah
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade200.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tips_and_updates_rounded, color: Colors.orange.shade800, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Temukan panduan, modul, dan jurnal kehutanan di sini. Anda juga dapat membagikan materi untuk pengguna lain.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Tampilan Filter Kategori yang Interaktif
            const Text(
              'Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _daftarKategori.map((kategori) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        // Memicu perubahan state (refresh UI) saat kategori ditekan
                        setState(() {
                          _kategoriAktif = kategori;
                        });
                      },
                      child: _KategoriChip(
                        label: kategori,
                        isActive: _kategoriAktif == kategori,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
            
            // Subtitle Hasil
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _kategoriAktif == 'Semua' ? 'Materi Terbaru' : 'Materi $_kategoriAktif',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '${materiDitampilkan.length} File',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // List Materi Dinamis
            if (materiDitampilkan.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada materi untuk kategori ini.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...materiDitampilkan.map((materi) => _MateriCard(
                judul: materi['judul'],
                penulis: materi['penulis'],
                kategori: materi['kategori'],
                tipe: materi['tipe'],
                ukuran: materi['ukuran'],
                warna: materi['warna'],
              )).toList(),

            const SizedBox(height: 80), // Ruang ekstra di bawah untuk FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormUpload(context),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: const Text(
          'Upload Materi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// Widget untuk Chip Kategori
class _KategoriChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _KategoriChip({
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Animasi perubahan warna dibuat menggunakan AnimatedContainer agar transisinya mulus
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1B5E20) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? const Color(0xFF1B5E20) : Colors.grey.shade300,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1B5E20).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade700,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _MateriCard extends StatelessWidget {
  final String judul;
  final String penulis;
  final String kategori;
  final String tipe;
  final String ukuran;
  final Color warna;

  const _MateriCard({
    required this.judul,
    required this.penulis,
    required this.kategori,
    required this.tipe,
    required this.ukuran,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Aksi ketika card ditekan
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon File
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tipe == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                          color: warna,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tipe,
                          style: TextStyle(
                            color: warna,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text Konten
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Kategori
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          kategori,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF212121),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              penulis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Action Button & Size
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.download_rounded),
                        color: const Color(0xFF1B5E20),
                        iconSize: 22,
                        splashRadius: 24,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mengunduh $judul...'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ukuran,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}