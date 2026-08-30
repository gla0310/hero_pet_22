import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import 'whatsapp_helper.dart';

/// يعرض للموظف مباشرة بعد اعتماد تسجيل الدخول/الخروج خانة "إرسال للعميل"
/// مع نص الرسالة الجاهزة - لا تُرسل تلقائياً، الموظف هو من يقرر.
class SendToClientPrompt {
  static Future<void> show({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إرسال للعميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text(message),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.chat),
                    label: const Text('إرسال عبر واتساب'),
                    onPressed: () async {
                      final result = await WhatsAppHelper.openWhatsAppWithMessage(phone: phone, message: message);
                      if (!ctx.mounted) return;
                      if (result == WhatsAppOpenResult.notInstalled) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('تعذّر فتح واتساب. يمكنك نسخ الرسالة وإرسالها يدوياً.')),
                        );
                      } else {
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم نسخ الرسالة')));
                    },
                    child: const Icon(Icons.copy, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تخطي'),
            ),
          ],
        ),
      ),
    );
  }
}
