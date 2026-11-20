<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    private function ensureAdmin(Request $request)
    {
        $user = $request->user();
        if (!$user || strtolower((string) $user->role) !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Akses ditolak. Fitur ini khusus untuk Administrator.',
            ], 403);
        }
        return null;
    }

    private function formatUser(User $user): array
    {
        return [
            'id' => (string) $user->id,
            'nip' => (string) ($user->nip ?? ''),
            'name' => (string) $user->name,
            'email' => (string) $user->email,
            'whatsapp' => (string) ($user->whatsapp_number ?? ''),
            'wilayah' => (string) ($user->wilayah ?? 'CDK Wilayah Garut'),
            'role' => (string) ($user->role ?? 'user'),
            'status' => (string) ($user->status ?? 'Aktif'),
            'avatar' => (string) ($user->avatar ?? ''),
            'created_at' => $user->created_at?->toIso8601String(),
            'updated_at' => $user->updated_at?->toIso8601String(),
        ];
    }

    public function index(Request $request)
    {
        if ($denied = $this->ensureAdmin($request)) {
            return $denied;
        }

        $query = User::query();
        if ($request->filled('search')) {
            $search = trim($request->query('search'));
            $query->where(function ($sub) use ($search) {
                $sub->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('nip', 'like', "%{$search}%")
                    ->orWhere('wilayah', 'like', "%{$search}%");
            });
        }
        if ($request->filled('role') && strtolower($request->query('role')) !== 'semua') {
            $query->where('role', $request->query('role'));
        }
        if ($request->filled('status') && strtolower($request->query('status')) !== 'semua') {
            $query->where('status', $request->query('status'));
        }

        $perPage = max(1, min((int) $request->query('per_page', 50), 100));
        $paginated = $query->orderByDesc('id')->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Daftar pengguna berhasil dimuat',
            'data' => collect($paginated->items())->map(fn (User $u) => $this->formatUser($u))->values(),
            'meta' => [
                'current_page' => $paginated->currentPage(),
                'last_page' => $paginated->lastPage(),
                'per_page' => $paginated->perPage(),
                'total' => $paginated->total(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        if ($denied = $this->ensureAdmin($request)) {
            return $denied;
        }

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => 'nullable|string|min:6|max:100',
            'nip' => 'nullable|string|max:50',
            'whatsapp' => 'nullable|string|max:25',
            'wilayah' => 'nullable|string|max:150',
            'role' => 'nullable|string|max:50',
            'status' => 'nullable|in:Aktif,Nonaktif',
        ]);

        $user = User::create([
            'name' => trim($validated['name']),
            'email' => strtolower(trim($validated['email'])),
            'password' => Hash::make(!empty($validated['password']) ? $validated['password'] : Str::random(12)),
            'nip' => trim((string) ($validated['nip'] ?? '')),
            'whatsapp_number' => trim((string) ($validated['whatsapp'] ?? '')),
            'wilayah' => trim((string) ($validated['wilayah'] ?? 'CDK Wilayah Garut')),
            'role' => trim((string) ($validated['role'] ?? 'user')),
            'status' => $validated['status'] ?? 'Aktif',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pengguna berhasil ditambahkan',
            'data' => $this->formatUser($user),
        ], 201);
    }

    public function update(Request $request, $id)
    {
        if ($denied = $this->ensureAdmin($request)) {
            return $denied;
        }

        $user = User::find($id);
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Pengguna tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'email' => ['sometimes', 'required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => 'nullable|string|min:6|max:100',
            'nip' => 'nullable|string|max:50',
            'whatsapp' => 'nullable|string|max:25',
            'wilayah' => 'nullable|string|max:150',
            'role' => 'nullable|string|max:50',
            'status' => 'nullable|in:Aktif,Nonaktif',
        ]);

        if ($user->id === $request->user()->id) {
            if (isset($validated['status']) && $validated['status'] !== 'Aktif') {
                return response()->json([
                    'success' => false,
                    'message' => 'Anda tidak dapat menonaktifkan akun admin yang sedang digunakan.',
                ], 422);
            }
            if (isset($validated['role']) && strtolower($validated['role']) !== 'admin') {
                return response()->json([
                    'success' => false,
                    'message' => 'Anda tidak dapat mengubah peran akun admin yang sedang digunakan.',
                ], 422);
            }
        }

        $updateData = [
            'name' => array_key_exists('name', $validated) ? trim($validated['name']) : $user->name,
            'email' => array_key_exists('email', $validated) ? strtolower(trim($validated['email'])) : $user->email,
            'nip' => array_key_exists('nip', $validated) ? trim((string) $validated['nip']) : $user->nip,
            'whatsapp_number' => array_key_exists('whatsapp', $validated) ? trim((string) $validated['whatsapp']) : $user->whatsapp_number,
            'wilayah' => array_key_exists('wilayah', $validated) ? trim((string) $validated['wilayah']) : $user->wilayah,
            'role' => array_key_exists('role', $validated) ? trim((string) $validated['role']) : $user->role,
            'status' => $validated['status'] ?? $user->status,
        ];
        if (!empty($validated['password'])) {
            $updateData['password'] = Hash::make($validated['password']);
        }
        $user->update($updateData);

        return response()->json([
            'success' => true,
            'message' => 'Data pengguna berhasil diperbarui',
            'data' => $this->formatUser($user->fresh()),
        ]);
    }

    public function destroy(Request $request, $id)
    {
        if ($denied = $this->ensureAdmin($request)) {
            return $denied;
        }

        $user = User::find($id);
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Pengguna tidak ditemukan'], 404);
        }
        if ($user->id === $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak dapat menghapus akun admin yang sedang login.',
            ], 422);
        }

        $reportCount = Report::where('user_id', $user->id)->count();
        if ($reportCount > 0) {
            $user->update(['status' => 'Nonaktif']);
            return response()->json([
                'success' => true,
                'deactivated' => true,
                'message' => "Akun memiliki {$reportCount} laporan di database. Status akun diubah menjadi Nonaktif agar data laporan tetap aman.",
                'data' => $this->formatUser($user->fresh()),
            ]);
        }
        $user->delete();

        return response()->json([
            'success' => true,
            'deactivated' => false,
            'message' => 'Pengguna berhasil dihapus dari database',
        ]);
    }

    public function monitoring(Request $request)
    {
        if ($denied = $this->ensureAdmin($request)) {
            return $denied;
        }

        $totalUsers = User::count();
        $activeUsers = User::where('status', 'Aktif')->count();
        $reportBaseQuery = Report::query();
        if ($request->filled('date_from')) {
            $reportBaseQuery->whereDate('activity_date', '>=', $request->query('date_from'));
        }
        if ($request->filled('date_to')) {
            $reportBaseQuery->whereDate('activity_date', '<=', $request->query('date_to'));
        }
        if ($request->filled('status') && strtolower($request->query('status')) !== 'semua') {
            $reportBaseQuery->where('status', $request->query('status'));
        }

        $totalReports = (clone $reportBaseQuery)->count();
        $pendingReports = (clone $reportBaseQuery)->whereIn('status', ['draft', 'terkirim'])->count();
        $processedReports = (clone $reportBaseQuery)->whereIn('status', ['diperiksa', 'disetujui', 'ditolak'])->count();

        $photoCols = ['id', 'report_id', 'photo', 'latitude', 'longitude'];
        if (Schema::hasColumn('report_photos', 'address')) {
            $photoCols[] = 'address';
        }
        $recentReports = (clone $reportBaseQuery)
            ->with([
                'user:id,name,email,role,wilayah',
                'category:id,name',
                'photos:' . implode(',', $photoCols),
            ])
            ->latest()->limit(20)->get();

        $statsByPeriod = (clone $reportBaseQuery)
            ->select(DB::raw('DATE(activity_date) as periode'), DB::raw('COUNT(*) as total'))
            ->groupBy(DB::raw('DATE(activity_date)'))
            ->orderByDesc('periode')->limit(7)->get();

        $lastActiveUsers = User::select('id', 'name', 'email', 'role', 'status', 'wilayah', 'updated_at')
            ->withCount('reports')
            ->withMax('reports', 'created_at')
            ->orderByDesc('reports_max_created_at')
            ->orderByDesc('updated_at')
            ->limit(10)->get()->map(fn ($u) => [
                'id' => (string) $u->id,
                'name' => $u->name,
                'email' => $u->email,
                'role' => $u->role ?? 'user',
                'status' => $u->status ?? 'Aktif',
                'wilayah' => $u->wilayah ?? 'CDK Wilayah Garut',
                'reports_count' => (int) $u->reports_count,
                'last_activity_at' => $u->reports_max_created_at ?? $u->updated_at?->toDateTimeString(),
            ]);

        return response()->json([
            'success' => true,
            'data' => [
                'summary' => [
                    'total_users' => $totalUsers,
                    'active_users' => $activeUsers,
                    'inactive_users' => $totalUsers - $activeUsers,
                    'total_reports' => $totalReports,
                    'pending_reports' => $pendingReports,
                    'processed_reports' => $processedReports,
                ],
                'stats_by_period' => $statsByPeriod,
                'recent_reports' => $recentReports,
                'last_active_users' => $lastActiveUsers,
            ],
        ]);
    }
}
