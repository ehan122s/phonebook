<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json([
                'success' => true,
                'message' => 'Data notifikasi berhasil diambil',
                'data' => [],
                'unread_count' => 0,
            ]);
        }

        $userId = $request->user()->id;

        $notifications = AppNotification::where('user_id', $userId)
            ->orderByDesc('created_at')
            ->get();

        $unreadCount = $notifications->where('is_read', false)->count();

        return response()->json([
            'success' => true,
            'message' => 'Data notifikasi berhasil diambil',
            'data' => $notifications,
            'unread_count' => $unreadCount,
        ]);
    }

    public function store(Request $request)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json([
                'success' => false,
                'message' => 'Tabel app_notifications belum dimigrasi',
            ], 503);
        }

        $validated = $request->validate([
            'type' => 'nullable|string|max:50',
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'reference_id' => 'nullable|string|max:100',
            'metadata' => 'nullable|array',
            'is_read' => 'nullable|boolean',
        ]);

        $notification = AppNotification::create([
            'user_id' => $request->user()->id,
            'type' => $validated['type'] ?? 'umum',
            'title' => $validated['title'],
            'message' => $validated['message'],
            'reference_id' => $validated['reference_id'] ?? null,
            'metadata' => $validated['metadata'] ?? null,
            'is_read' => $validated['is_read'] ?? false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Notifikasi berhasil disimpan',
            'data' => $notification,
        ], 201);
    }

    public function markAsRead(Request $request, $id)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json(['success' => true]);
        }

        $notification = AppNotification::where('user_id', $request->user()->id)
            ->find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notifikasi tidak ditemukan',
            ], 404);
        }

        $notification->update(['is_read' => true]);

        return response()->json([
            'success' => true,
            'message' => 'Notifikasi ditandai telah dibaca',
            'data' => $notification,
        ]);
    }

    public function markAllAsRead(Request $request)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json(['success' => true]);
        }

        AppNotification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json([
            'success' => true,
            'message' => 'Seluruh notifikasi ditandai telah dibaca',
        ]);
    }

    public function destroy(Request $request, $id)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json([
                'success' => true,
                'message' => 'Notifikasi berhasil dihapus',
            ]);
        }

        $notification = AppNotification::where('user_id', $request->user()->id)
            ->where(function ($query) use ($id) {
                $query->where('id', $id)
                    ->orWhere('reference_id', (string) $id);
            })
            ->first();

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notifikasi tidak ditemukan',
            ], 404);
        }

        $notification->delete();

        return response()->json([
            'success' => true,
            'message' => 'Notifikasi berhasil dihapus',
        ]);
    }

    public function destroyAll(Request $request)
    {
        if (!Schema::hasTable('app_notifications')) {
            return response()->json([
                'success' => true,
                'message' => 'Seluruh notifikasi berhasil dihapus',
                'deleted_count' => 0,
            ]);
        }

        $deletedCount = AppNotification::where('user_id', $request->user()->id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Seluruh notifikasi berhasil dihapus',
            'deleted_count' => $deletedCount,
        ]);
    }
}
