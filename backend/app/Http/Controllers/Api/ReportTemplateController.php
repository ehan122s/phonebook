<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ReportTemplate;
use Illuminate\Http\Request;

class ReportTemplateController extends Controller
{
    /**
     * Default templates seeded automatically when table is empty.
     */
    private static function getDefaultTemplates(): array
    {
        return [
            [
                'name' => 'Laporan Penyuluhan',
                'category' => 'Penyuluhan',
                'icon_key' => 'groups',
                'description' => 'Template laporan kegiatan penyuluhan kehutanan dan pendampingan Kelompok Tani Hutan (KTH).',
                'default_title' => 'Penyuluhan Kehutanan & Pendampingan KTH',
                'require_photo' => true,
                'require_location' => true,
                'fields_config' => [
                    [
                        'id' => 'kth_sasaran',
                        'label' => 'Kelompok Tani Hutan (KTH) / Sasaran',
                        'type' => 'text',
                        'placeholder' => 'Contoh: KTH Bina Mandiri Makmur',
                        'description' => 'Nama KTH atau kelompok masyarakat yang didampingi',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'materi_penyuluhan',
                        'label' => 'Materi Penyuluhan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Budidaya Tanaman MPTS & Konservasi Sumber Air',
                        'description' => 'Uraian pokok topik materi bimbingan teknis',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'jumlah_peserta',
                        'label' => 'Jumlah Peserta (Orang)',
                        'type' => 'number',
                        'placeholder' => 'Contoh: 25',
                        'description' => 'Total peserta yang hadir dalam kegiatan',
                        'required' => false,
                        'options' => [],
                    ],
                    [
                        'id' => 'hasil_tindak_lanjut',
                        'label' => 'Hasil & Tindak Lanjut',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Terbentuk kesepakatan jadwal penanaman dan pemeliharaan bibit.',
                        'description' => 'Ringkasan hasil diskusi serta rencana tindak lanjut',
                        'required' => true,
                        'options' => [],
                    ],
                ],
                'placeholders' => [
                    'Kelompok Tani Hutan (KTH) / Sasaran',
                    'Materi Penyuluhan',
                    'Jumlah Peserta (Orang)',
                    'Hasil & Tindak Lanjut',
                ],
                'template_body' => "LAPORAN KEGIATAN PENYULUHAN KEHUTANAN\nCabang Dinas Kehutanan Wilayah V\n\n1. Kelompok Sasaran / KTH : {{Kelompok Tani Hutan (KTH) / Sasaran}}\n2. Materi Penyuluhan      : {{Materi Penyuluhan}}\n3. Jumlah Peserta         : {{Jumlah Peserta (Orang)}}\n4. Hasil & Tindak Lanjut  :\n{{Hasil & Tindak Lanjut}}",
                'is_active' => true,
            ],
            [
                'name' => 'Laporan TRK',
                'category' => 'TRK & Rehabilitasi',
                'icon_key' => 'park',
                'description' => 'Template laporan kegiatan Tenaga Rimbawan Kehutanan (TRK), rehabilitasi lahan kritis, dan penanaman.',
                'default_title' => 'Pelaksanaan Kegiatan TRK & Rehabilitasi Lahan',
                'require_photo' => true,
                'require_location' => true,
                'fields_config' => [
                    [
                        'id' => 'blok_petak',
                        'label' => 'Blok / Petak Kawasan Rehabilitasi',
                        'type' => 'text',
                        'placeholder' => 'Contoh: Blok Pasir Angin Petak 12',
                        'description' => 'Lokasi spesifik petak rehabilitasi',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'jenis_bibit',
                        'label' => 'Jenis & Jumlah Bibit Tanaman',
                        'type' => 'text',
                        'placeholder' => 'Contoh: Alpukat (500 btg), Kopi Arabika (1000 btg)',
                        'description' => 'Rincian jenis bibit dan volumenya',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'luas_area',
                        'label' => 'Luas Area Penanaman (Ha)',
                        'type' => 'number',
                        'placeholder' => 'Contoh: 2.5',
                        'description' => 'Perkiraan luas hektar penanaman',
                        'required' => false,
                        'options' => [],
                    ],
                    [
                        'id' => 'kondisi_tanaman',
                        'label' => 'Kondisi Tanaman & Evaluasi Lapangan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Bibit ditanam dengan pola agroforestri, kondisi tanah cukup basah.',
                        'description' => 'Uraian pertumbuhan dan kendala lapangan',
                        'required' => true,
                        'options' => [],
                    ],
                ],
                'placeholders' => [
                    'Blok / Petak Kawasan Rehabilitasi',
                    'Jenis & Jumlah Bibit Tanaman',
                    'Luas Area Penanaman (Ha)',
                    'Kondisi Tanaman & Evaluasi Lapangan',
                ],
                'template_body' => "LAPORAN PELAKSANAAN TRK & REHABILITASI HUTAN\nCabang Dinas Kehutanan Wilayah V\n\n1. Blok / Petak Kawasan : {{Blok / Petak Kawasan Rehabilitasi}}\n2. Jenis & Jumlah Bibit : {{Jenis & Jumlah Bibit Tanaman}}\n3. Luas Area (Ha)       : {{Luas Area Penanaman (Ha)}}\n4. Kondisi & Evaluasi   :\n{{Kondisi Tanaman & Evaluasi Lapangan}}",
                'is_active' => true,
            ],
            [
                'name' => 'Laporan Monitoring',
                'category' => 'Monitoring & Patroli',
                'icon_key' => 'forest',
                'description' => 'Template laporan hasil monitoring kawasan hutan, pemeriksaan patok batas, dan pengamanan hutan.',
                'default_title' => 'Monitoring & Patroli Kawasan Hutan',
                'require_photo' => true,
                'require_location' => true,
                'fields_config' => [
                    [
                        'id' => 'kawasan_titik',
                        'label' => 'Kawasan / Titik Pantau Hutan',
                        'type' => 'text',
                        'placeholder' => 'Contoh: Kawasan Lindung Lereng Gunung Guntur',
                        'description' => 'Nama kawasan atau titik pemeriksaan',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'kondisi_tegakan',
                        'label' => 'Kondisi Tegakan & Patok Batas',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Patok batas no. 45-50 aman, vegetasi tegakan utuh.',
                        'description' => 'Kondisi kerapatan pohon dan batas wilayah',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'temuan_lapangan',
                        'label' => 'Temuan Lapangan / Kerawanan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Tidak ditemukan tanda perambahan atau kebakaran hutan.',
                        'description' => 'Catatan potensi gangguan keamanan hutan',
                        'required' => false,
                        'options' => [],
                    ],
                    [
                        'id' => 'rekomendasi_tindakan',
                        'label' => 'Rekomendasi Tindakan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Patroli berkala perlu dilanjutkan bersama KTH setempat.',
                        'description' => 'Saran penanganan operasional berikutnya',
                        'required' => true,
                        'options' => [],
                    ],
                ],
                'placeholders' => [
                    'Kawasan / Titik Pantau Hutan',
                    'Kondisi Tegakan & Patok Batas',
                    'Temuan Lapangan / Kerawanan',
                    'Rekomendasi Tindakan',
                ],
                'template_body' => "LAPORAN MONITORING KAWASAN HUTAN\nCabang Dinas Kehutanan Wilayah V\n\n1. Kawasan / Titik Pantau    : {{Kawasan / Titik Pantau Hutan}}\n2. Kondisi Tegakan & Patok   : {{Kondisi Tegakan & Patok Batas}}\n3. Temuan Lapangan           : {{Temuan Lapangan / Kerawanan}}\n4. Rekomendasi Tindakan      :\n{{Rekomendasi Tindakan}}",
                'is_active' => true,
            ],
            [
                'name' => 'Laporan Kegiatan',
                'category' => 'Kegiatan Lapangan',
                'icon_key' => 'event_note',
                'description' => 'Template laporan kegiatan teknis, sosialisasi masyarakat, dan koordinasi lapangan lainnya.',
                'default_title' => 'Laporan Kegiatan Operasional Lapangan',
                'require_photo' => false,
                'require_location' => true,
                'fields_config' => [
                    [
                        'id' => 'nama_kegiatan',
                        'label' => 'Nama Kegiatan & Instansi Terkait',
                        'type' => 'text',
                        'placeholder' => 'Contoh: Rapat Koordinasi Penyuluh & Balai Pengelolaan DAS',
                        'description' => 'Agenda acara dan mitra pelaksana',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'tujuan_kegiatan',
                        'label' => 'Tujuan Pelaksanaan Kegiatan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Penyelarasan target rehabilitasi hutan tahun berjalan.',
                        'description' => 'Maksud utama penyelenggaraan kegiatan',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'ringkasan_hasil',
                        'label' => 'Ringkasan Hasil Kegiatan',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Disepakati pembagian kuota bibit per wilayah kerja.',
                        'description' => 'Kesimpulan utama dan poin penting kegiatan',
                        'required' => true,
                        'options' => [],
                    ],
                ],
                'placeholders' => [
                    'Nama Kegiatan & Instansi Terkait',
                    'Tujuan Pelaksanaan Kegiatan',
                    'Ringkasan Hasil Kegiatan',
                ],
                'template_body' => "LAPORAN KEGIATAN LAPANGAN\nCabang Dinas Kehutanan Wilayah V\n\n1. Kegiatan & Pihak Terkait : {{Nama Kegiatan & Instansi Terkait}}\n2. Tujuan Kegiatan          : {{Tujuan Pelaksanaan Kegiatan}}\n3. Ringkasan Hasil          :\n{{Ringkasan Hasil Kegiatan}}",
                'is_active' => true,
            ],
            [
                'name' => 'Laporan Kejadian',
                'category' => 'Kejadian Khusus',
                'icon_key' => 'warning',
                'description' => 'Template laporan kejadian darurat, kebakaran hutan, bencana alam, atau kondisi khusus di lapangan.',
                'default_title' => 'Laporan Kejadian Khusus / Darurat Kehutanan',
                'require_photo' => true,
                'require_location' => true,
                'fields_config' => [
                    [
                        'id' => 'jenis_kejadian',
                        'label' => 'Jenis Kejadian',
                        'type' => 'dropdown',
                        'placeholder' => 'Pilih jenis kejadian...',
                        'description' => 'Kategori insiden lapangan',
                        'required' => true,
                        'options' => ['Kebakaran Hutan & Lahan', 'Tanah Longsor', 'Perambahan Hutan', 'Pohon Tumbang', 'Lainnya'],
                    ],
                    [
                        'id' => 'perkiraan_dampak',
                        'label' => 'Perkiraan Dampak / Luas Terdampak',
                        'type' => 'text',
                        'placeholder' => 'Contoh: Luas terdampak ±0.8 Ha, tidak ada korban jiwa.',
                        'description' => 'Estimasi kerugian fisik atau luasan area terdampak',
                        'required' => true,
                        'options' => [],
                    ],
                    [
                        'id' => 'tindakan_penanganan',
                        'label' => 'Tindakan Penanganan Awal',
                        'type' => 'textarea',
                        'placeholder' => 'Contoh: Pemadaman manual bersama MPA dan warga sekitar.',
                        'description' => 'Langkah cepat penanggulangan yang telah dilakukan',
                        'required' => true,
                        'options' => [],
                    ],
                ],
                'placeholders' => [
                    'Jenis Kejadian',
                    'Perkiraan Dampak / Luas Terdampak',
                    'Tindakan Penanganan Awal',
                ],
                'template_body' => "LAPORAN KEJADIAN KHUSUS KEHUTANAN\nCabang Dinas Kehutanan Wilayah V\n\n1. Jenis Kejadian        : {{Jenis Kejadian}}\n2. Dampak / Luas         : {{Perkiraan Dampak / Luas Terdampak}}\n3. Penanganan Awal       :\n{{Tindakan Penanganan Awal}}",
                'is_active' => true,
            ],
        ];
    }

    /**
     * Display a listing of all active report templates from Supabase PostgreSQL.
     */
    public function index()
    {
        $count = ReportTemplate::query()->count();
        if ($count === 0) {
            foreach (self::getDefaultTemplates() as $tpl) {
                ReportTemplate::create($tpl);
            }
        }

        $templates = ReportTemplate::query()
            ->where('is_active', true)
            ->orderBy('id', 'asc')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Daftar template laporan berhasil diambil',
            'data' => $templates,
        ]);
    }

    /**
     * Display the specified template.
     */
    public function show($id)
    {
        $template = ReportTemplate::find($id);

        if (!$template) {
            return response()->json([
                'success' => false,
                'message' => 'Template laporan tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $template,
        ]);
    }

    /**
     * Store a newly created template in PostgreSQL Supabase.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'nullable|string|max:255',
            'title' => 'nullable|string|max:255',
            'category' => 'required|string|max:255',
            'description' => 'nullable|string',
            'fields_config' => 'nullable|array',
            'placeholders' => 'nullable|array',
            'template_body' => 'nullable|string',
            'icon_key' => 'nullable|string|max:100',
            'default_title' => 'nullable|string|max:255',
            'require_photo' => 'nullable|boolean',
            'require_location' => 'nullable|boolean',
            'file_name' => 'nullable|string|max:255',
            'file_path' => 'nullable|string',
            'file_base64' => 'nullable|string',
        ]);

        $name = $validated['name'] ?? $validated['title'] ?? 'Laporan Kegiatan';
        $user = $request->user();

        // Convert fields_config into string placeholders if placeholders array is not provided
        $fieldsConfig = $validated['fields_config'] ?? [];
        $placeholders = $validated['placeholders'] ?? [];
        if (empty($placeholders) && !empty($fieldsConfig)) {
            foreach ($fieldsConfig as $item) {
                if (is_array($item) && isset($item['label'])) {
                    $placeholders[] = $item['label'];
                } elseif (is_string($item)) {
                    $placeholders[] = $item;
                }
            }
        }

        $template = ReportTemplate::create([
            'name' => $name,
            'category' => $validated['category'],
            'description' => $validated['description'] ?? null,
            'fields_config' => $fieldsConfig,
            'placeholders' => $placeholders,
            'template_body' => $validated['template_body'] ?? null,
            'icon_key' => $validated['icon_key'] ?? 'description',
            'default_title' => $validated['default_title'] ?? null,
            'require_photo' => $validated['require_photo'] ?? true,
            'require_location' => $validated['require_location'] ?? true,
            'file_name' => $validated['file_name'] ?? null,
            'file_path' => $validated['file_path'] ?? null,
            'file_base64' => $validated['file_base64'] ?? null,
            'is_active' => true,
            'uploaded_by' => $user ? $user->id : null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Template laporan berhasil disimpan ke database',
            'data' => $template,
        ], 201);
    }

    /**
     * Update an existing report template in PostgreSQL Supabase.
     */
    public function update(Request $request, $id)
    {
        // Try finding by primary key ID, or fallback to matching name
        $template = is_numeric($id) ? ReportTemplate::find($id) : null;
        if (!$template) {
            $template = ReportTemplate::where('name', $id)
                ->orWhere('id', (int) preg_replace('/\D/', '', $id))
                ->first();
        }

        if (!$template) {
            // If still not found, check if it's a new template with non-numeric client ID and create it
            return $this->store($request);
        }

        $validated = $request->validate([
            'name' => 'nullable|string|max:255',
            'title' => 'nullable|string|max:255',
            'category' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'fields_config' => 'nullable|array',
            'placeholders' => 'nullable|array',
            'template_body' => 'nullable|string',
            'icon_key' => 'nullable|string|max:100',
            'default_title' => 'nullable|string|max:255',
            'require_photo' => 'nullable|boolean',
            'require_location' => 'nullable|boolean',
            'is_active' => 'nullable|boolean',
            'file_name' => 'nullable|string|max:255',
            'file_path' => 'nullable|string',
            'file_base64' => 'nullable|string',
        ]);

        if (isset($validated['name']) || isset($validated['title'])) {
            $template->name = $validated['name'] ?? $validated['title'];
        }
        if (isset($validated['category'])) {
            $template->category = $validated['category'];
        }
        if (array_key_exists('description', $validated)) {
            $template->description = $validated['description'];
        }
        if (isset($validated['fields_config'])) {
            $template->fields_config = $validated['fields_config'];
            // Also keep placeholders in sync
            $placeholders = [];
            foreach ($validated['fields_config'] as $item) {
                if (is_array($item) && isset($item['label'])) {
                    $placeholders[] = $item['label'];
                } elseif (is_string($item)) {
                    $placeholders[] = $item;
                }
            }
            $template->placeholders = $placeholders;
        }
        if (isset($validated['placeholders'])) {
            $template->placeholders = $validated['placeholders'];
        }
        if (array_key_exists('template_body', $validated)) {
            $template->template_body = $validated['template_body'];
        }
        if (isset($validated['icon_key'])) {
            $template->icon_key = $validated['icon_key'];
        }
        if (array_key_exists('default_title', $validated)) {
            $template->default_title = $validated['default_title'];
        }
        if (isset($validated['require_photo'])) {
            $template->require_photo = (bool) $validated['require_photo'];
        }
        if (isset($validated['require_location'])) {
            $template->require_location = (bool) $validated['require_location'];
        }
        if (isset($validated['is_active'])) {
            $template->is_active = (bool) $validated['is_active'];
        }
        if (isset($validated['file_name'])) {
            $template->file_name = $validated['file_name'];
        }
        if (isset($validated['file_path'])) {
            $template->file_path = $validated['file_path'];
        }
        if (isset($validated['file_base64'])) {
            $template->file_base64 = $validated['file_base64'];
        }

        $template->save();

        return response()->json([
            'success' => true,
            'message' => 'Template laporan berhasil diperbarui di database Supabase',
            'data' => $template,
        ]);
    }

    /**
     * Remove the specified report template.
     */
    public function destroy($id)
    {
        $template = is_numeric($id) ? ReportTemplate::find($id) : null;
        if (!$template) {
            $template = ReportTemplate::where('name', $id)->first();
        }

        if (!$template) {
            return response()->json([
                'success' => false,
                'message' => 'Template tidak ditemukan',
            ], 404);
        }

        $template->update(['is_active' => false]);

        return response()->json([
            'success' => true,
            'message' => 'Template laporan berhasil dinonaktifkan',
        ]);
    }
}
