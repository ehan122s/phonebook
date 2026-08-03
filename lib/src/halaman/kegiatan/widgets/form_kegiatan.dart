import 'dart:io'; // Tambahkan ini untuk tipe File
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart'; // Tambahkan ini
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/category.dart';
import '../../../services/activity_repository.dart';
import '../../../services/category_repository.dart';
import '../../../services/garut_geojson_service.dart';
import '../../../widgets/glashmorp.dart';
import '../../../widgets/leaflet_map.dart'; 

class ActivityForm extends StatefulWidget {
  const ActivityForm({super.key, required this.repository});
  final ActivityRepository repository;
  
  @override
  State<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<ActivityForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _village = TextEditingController();
  final _district = TextEditingController();
  final _regency = TextEditingController();
  final _group = TextEditingController();
  final _participants = TextEditingController();
  final _material = TextEditingController();
  final _objective = TextEditingController();
  final _result = TextEditingController();
  final _obstacle = TextEditingController();
  final _followUp = TextEditingController();
  final _notes = TextEditingController();
  
  DateTime _date = DateTime.now();
  String? _categoryId;
  double? _latitude;
  double? _longitude;
  
  File? _photo; // Variabel penyimpan file foto
  
  late final Future<List<String>> _garutDistricts;
  bool _saving = false;
  
  @override
  void initState() {
    super.initState();
    _garutDistricts = GarutGeoJsonService().districts();
  }

  // --- FUNGSI PILIH FOTO ---
  Future<void> _pilihFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70, // Kompres ukuran agar tidak terlalu besar
    );
    
    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _gunakanLokasiSaya() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Layanan lokasi perangkat tidak aktif');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi belum diberikan');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _location.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    
    try {
      String? photoUrl;

      // --- LOGIKA UPLOAD FOTO KE SUPABASE STORAGE ---
      if (_photo != null) {
        final fileExtension = _photo!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        
        // Sesuaikan 'activity_photos' dengan nama bucket di Supabase kamu
        await Supabase.instance.client.storage
            .from('activity_photos') 
            .upload(fileName, _photo!);
            
        // Ambil Public URL setelah berhasil diupload
        photoUrl = Supabase.instance.client.storage
            .from('activity_photos')
            .getPublicUrl(fileName);
      }

      await widget.repository.create({
        'title': _title.text,
        'category_id': _categoryId,
        'activity_date': DateFormat('yyyy-MM-dd').format(_date),
        'location': _location.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'village': _village.text,
        'district': _district.text,
        'regency': _regency.text,
        'farmer_group': _group.text,
        'participant_count': int.tryParse(_participants.text) ?? 0,
        'material': _material.text,
        'objective': _objective.text,
        'result': _result.text,
        'obstacle': _obstacle.text,
        'follow_up': _followUp.text,
        'notes': _notes.text,
        // Pastikan kolom ini ada di database Supabase kamu:
        if (photoUrl != null) 'photo_url': photoUrl, 
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data kegiatan berhasil disimpan')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on StorageException catch (error) { // Tangkap error upload gambar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload gambar: ${error.message}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: KartuKaca(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Buat Kegiatan Baru', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: Form(
                    key: _form,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informasi Dasar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 16),
                          _inputTeks(_title, 'Judul Kegiatan'),
                          
                          FutureBuilder<List<Category>>(
                            future: CategoryRepository(Supabase.instance.client).list(),
                            builder: (context, snapshot) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                initialValue: _categoryId,
                                decoration: const InputDecoration(labelText: 'Jenis Kegiatan'),
                                items: snapshot.data?.map(
                                  (category) => DropdownMenuItem(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                                ).toList(),
                                onChanged: (value) => setState(() => _categoryId = value),
                                validator: (v) => v == null ? 'Wajib pilih kategori' : null,
                              ),
                            ),
                          ),

                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: const Text('Tanggal Pelaksanaan'),
                              subtitle: Text(
                                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_date),
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                              trailing: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: _date,
                                );
                                if (picked != null) setState(() => _date = picked);
                              },
                            ),
                          ),

                          // --- SEKSI DOKUMENTASI FOTO ---
                          const Divider(color: Colors.black12),
                          const SizedBox(height: 16),
                          const Text('Dokumentasi', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_photo != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _photo!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black26),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.black38),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: _pilihFoto,
                                icon: const Icon(Icons.add_a_photo),
                                label: Text(_photo == null ? 'Tambah Foto' : 'Ganti Foto'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // ------------------------------------

                          const Divider(color: Colors.black12),
                          const SizedBox(height: 16),
                          const Text('Lokasi & Wilayah', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 16),
                          
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(width: 300, child: _opsionalTeks(_location, 'Titik Koordinat (Opsional)')),
                              FilledButton.icon(
                                onPressed: _gunakanLokasiSaya,
                                icon: const Icon(Icons.my_location, size: 18),
                                label: Text(_latitude == null ? 'Deteksi Lokasi' : 'Perbarui Lokasi'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (_latitude != null && _longitude != null) ...[
                            SizedBox(
                              height: 200,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: LeafletMap(latitude: _latitude, longitude: _longitude),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          Row(
                            children: [
                              Expanded(child: _inputTeks(_village, 'Desa')),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FutureBuilder<List<String>>(
                                  future: _garutDistricts,
                                  builder: (context, snapshot) => snapshot.hasData
                                      ? Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _district.text.isEmpty ? null : _district.text,
                                            decoration: const InputDecoration(labelText: 'Kecamatan'),
                                            items: snapshot.data!.map(
                                              (name) => DropdownMenuItem(value: name, child: Text(name)),
                                            ).toList(),
                                            onChanged: (value) => _district.text = value ?? '',
                                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                                          ),
                                        )
                                      : _inputTeks(_district, 'Kecamatan'),
                                ),
                              ),
                            ],
                          ),
                          _inputTeks(_regency, 'Kabupaten (Default: Garut)'),

                          const Divider(color: Colors.black12),
                          const SizedBox(height: 16),
                          const Text('Detail Pelaksanaan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(flex: 2, child: _opsionalTeks(_group, 'Nama Kelompok Tani')),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _participants,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Jml Peserta'),
                                ),
                              ),
                            ],
                          ),
                          
                          _opsionalTeks(_material, 'Materi Penyuluhan', baris: 3),
                          _opsionalTeks(_objective, 'Tujuan Kegiatan', baris: 3),
                          _opsionalTeks(_result, 'Hasil Kegiatan', baris: 3),
                          _opsionalTeks(_obstacle, 'Kendala di Lapangan', baris: 3),
                          _opsionalTeks(_followUp, 'Tindak Lanjut', baris: 3),
                          _opsionalTeks(_notes, 'Catatan Tambahan', baris: 2),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _saving ? null : _simpan,
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan Kegiatan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _inputTeks(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
        ),
      );

  Widget _opsionalTeks(TextEditingController controller, String label, {int baris = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          maxLines: baris,
          decoration: InputDecoration(labelText: label),
        ),
      );
}