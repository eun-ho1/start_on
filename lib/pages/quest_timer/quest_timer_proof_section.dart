import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart' as neu;

class QuestTimerProofSection extends StatelessWidget {
  const QuestTimerProofSection({
    super.key,
    required this.proofImagePath,
    required this.isCompleting,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onClearImage,
  });

  final String? proofImagePath;
  final bool isCompleting;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '인증 사진',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2940),
                ),
              ),
            ),
            _QuestTimerProofIconButton(
              icon: Icons.photo_camera_outlined,
              onTap: isCompleting ? null : onPickCamera,
            ),
            const SizedBox(width: 10),
            _QuestTimerProofIconButton(
              icon: Icons.photo_library_outlined,
              onTap: isCompleting ? null : onPickGallery,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (proofImagePath == null)
          neu.Neumorphic(
            style: neu.NeumorphicStyle(
              depth: -5,
              intensity: 0.92,
              surfaceIntensity: 0.16,
              color: const Color(0xFFF8FBFF),
              shadowLightColor: Colors.white.withValues(alpha: 0.98),
              shadowDarkColor: const Color(0xFFD5DDEA),
              boxShape: neu.NeumorphicBoxShape.roundRect(
                BorderRadius.circular(18),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: const Column(
                  children: [
                    Icon(
                      Icons.upload_outlined,
                      size: 34,
                      color: Color(0xFF8E9AAE),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '카메라 촬영 또는 갤러리에서 선택',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7E899D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              neu.Neumorphic(
                style: neu.NeumorphicStyle(
                  depth: 7,
                  intensity: 0.9,
                  surfaceIntensity: 0.16,
                  color: const Color(0xFFF8FBFF),
                  shadowLightColor: Colors.white.withValues(alpha: 0.98),
                  shadowDarkColor: const Color(0xFFD5DDEA),
                  boxShape: neu.NeumorphicBoxShape.roundRect(
                    BorderRadius.circular(18),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(proofImagePath!),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: _QuestTimerProofIconButton(
                  icon: Icons.close_rounded,
                  onTap: isCompleting ? null : onClearImage,
                  size: 38,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _QuestTimerProofIconButton extends StatelessWidget {
  const _QuestTimerProofIconButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: neu.Neumorphic(
          style: neu.NeumorphicStyle(
            depth: 6,
            intensity: 0.9,
            surfaceIntensity: 0.18,
            color: const Color(0xFFF8FBFF),
            shadowLightColor: Colors.white.withValues(alpha: 0.98),
            shadowDarkColor: const Color(0xFFD5DDEA),
            boxShape: const neu.NeumorphicBoxShape.circle(),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 20, color: const Color(0xFF667085)),
          ),
        ),
      ),
    );
  }
}
