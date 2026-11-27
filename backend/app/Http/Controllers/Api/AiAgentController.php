<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AiAgentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class AiAgentController extends Controller
{
    public function __construct(
        private readonly AiAgentService $agent
    ) {}

    /**
     * Endpoint chat AI Agent Phonebook (memerlukan autentikasi Sanctum).
     */
    public function chat(Request $request)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi login tidak valid. Silakan login kembali.',
            ], 401);
        }

        $validated = $request->validate([
            'message' => ['required', 'string', 'min:1', 'max:2000'],
            'history' => ['nullable', 'array', 'max:20'],
            'history.*.role' => ['required_with:history', 'string', 'in:user,assistant'],
            'history.*.content' => ['required_with:history', 'string', 'max:4000'],
        ], [
            'message.required' => 'Pesan tidak boleh kosong.',
            'message.max' => 'Pesan maksimal terdiri dari 2000 karakter.',
            'history.max' => 'Riwayat percakapan melebihi batas maksimal.',
        ]);

        try {
            $result = $this->agent->chat(
                $user,
                $validated['message'],
                $validated['history'] ?? []
            );

            return response()->json([
                'success' => true,
                'message' => 'Respons AI berhasil dihasilkan.',
                'data' => [
                    'reply' => $result['reply'],
                    'used_tools' => $result['used_tools'],
                    'model' => $result['model'],
                ],
            ]);
        } catch (RuntimeException $e) {
            $msg = $e->getMessage();
            $statusCode = str_contains(strtolower($msg), 'batas permintaan') ? 429 : 503;

            return response()->json([
                'success' => false,
                'message' => $msg,
            ], $statusCode);
        } catch (\Throwable $e) {
            Log::error('AiAgentController unexpected error', [
                'user_id' => $user->id,
                'type' => get_class($e),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Terjadi kendala saat memproses permintaan AI. Silakan coba lagi.',
            ], 500);
        }
    }
}
