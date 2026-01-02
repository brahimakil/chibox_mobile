import 'package:flutter/material.dart';

/// LuxeMarket Shadow System
class AppShadows {
  AppShadows._();

  // ============== BOX SHADOWS ==============
  static List<BoxShadow> xs = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> sm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> xl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.10),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> xxl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.12),
      blurRadius: 48,
      offset: const Offset(0, 24),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // Colored shadows
  static List<BoxShadow> primarySm = [
    BoxShadow(
      color: const Color(0xFFEE8C22).withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> primaryMd = [
    BoxShadow(
      color: const Color(0xFFEE8C22).withOpacity(0.30),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> goldSm = [
    BoxShadow(
      color: const Color(0xFFF59E0B).withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // Inner shadows for depth effect
  static List<BoxShadow> innerSm = [
    const BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
      spreadRadius: -1,
    ),
  ];

  // ============== DARK MODE SHADOWS ==============
  static List<BoxShadow> darkMd = [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> darkLg = [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.30),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.20),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];
}

