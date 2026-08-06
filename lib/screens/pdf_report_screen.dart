import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/customer.dart';
import '../utils/theme.dart';

/// Full-screen PDF report viewer for MCP Avadi CRM.
///
/// Generates a professional PDF from live customer data and displays it
/// inside the app using [PdfPreview] (which provides native share + download).
class PdfReportScreen extends StatelessWidget {
  const PdfReportScreen({
    super.key,
    required this.customers,
    required this.totalCustomers,
    required this.bookedCustomers,
    required this.registrationCompleted,
  });

  final List<Customer> customers;
  final int totalCustomers;
  final int bookedCustomers;
  final int registrationCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Customer Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PdfPreview(
        // ── PDF generation ──────────────────────────────────────
        build: (pageFormat) async {
          final bytes = await _generatePdf(pageFormat);
          return Uint8List.fromList(bytes);
        },

        // ── Toolbar customisation ───────────────────────────────
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'MCP_Avadi_Report_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf',

        // ── Styling ─────────────────────────────────────────────
        previewPageMargin: const EdgeInsets.all(12),
        actionBarTheme: PdfActionBarTheme(
          backgroundColor: AppColors.primary,
          iconColor: Colors.white,
          textStyle: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: const [],
      ),
    );
  }

  // ─── PDF Layout ────────────────────────────────────────────────

  Future<List<int>> _generatePdf(PdfPageFormat pageFormat) async {
    final pdf = pw.Document(
      title: 'MCP Avadi – Customer Report',
      author: 'MCP Avadi CRM',
    );

    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Colour palette (PdfColor)
    const primaryColor = PdfColor.fromInt(0xFF0D5C40);
    const goldColor = PdfColor.fromInt(0xFFD4A843);
    const headerBg = PdfColor.fromInt(0xFF0A4A33);
    const rowAlt = PdfColor.fromInt(0xFFF0F7F4);
    const borderColor = PdfColor.fromInt(0xFFCCDDD6);
    const textDark = PdfColor.fromInt(0xFF1A2E25);
    const textMuted = PdfColor.fromInt(0xFF6B8070);
    const bookedBg = PdfColor.fromInt(0xFFD4EDDA);
    const pendingBg = PdfColor.fromInt(0xFFFFF3CD);
    const completedBg = PdfColor.fromInt(0xFFCCE5FF);

    // ── Column widths (proportional) ────────────────────────────
    const cols = [
      0.03, // #
      0.14, // Name
      0.10, // Phone
      0.09, // Place
      0.10, // Lead By
      0.08, // Date
      0.09, // Booking
      0.10, // Registration
    ];

    final headers = [
      '#', 'Customer Name', 'Phone', 'Place',
      'Lead By', 'Date', 'Booking', 'Registration',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildHeader(
          ctx,
          primaryColor,
          goldColor,
          headerBg,
          textDark,
          generatedAt,
        ),
        footer: (ctx) => _buildFooter(ctx, primaryColor, textMuted, generatedAt),
        build: (ctx) => [
          // ── Summary cards ──────────────────────────────────────
          _buildSummaryRow(primaryColor, goldColor, textMuted),
          pw.SizedBox(height: 18),

          // ── Table ─────────────────────────────────────────────
          pw.Table(
            columnWidths: {
              for (int i = 0; i < cols.length; i++)
                i: pw.FlexColumnWidth(cols[i]),
            },
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: headers
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 6),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              // Data rows
              ...customers.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final bg = i.isEven ? PdfColors.white : rowAlt;
                final isBooked = c.bookingStatus == BookingStatus.booked;
                final isCompleted =
                    c.registrationStatus == RegistrationStatus.completed;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _cell('${i + 1}', textDark, fontSize: 7),
                    _cell(c.customerName, textDark),
                    _cell(c.phoneNumber, textDark, fontSize: 7),
                    _cell(c.place, textDark),
                    _cell(c.leadGivenBy, textDark),
                    _cell(c.formattedDate, textMuted, fontSize: 7),
                    _tagCell(
                      isBooked ? 'Booked' : 'Pending',
                      isBooked ? bookedBg : pendingBg,
                      isBooked ? primaryColor : goldColor,
                    ),
                    _tagCell(
                      isCompleted ? 'Done' : 'Pending',
                      isCompleted ? completedBg : pendingBg,
                      isCompleted ? PdfColor.fromInt(0xFF155CB6) : goldColor,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          // Total count
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${customers.length} customer${customers.length != 1 ? 's' : ''}',
              style: pw.TextStyle(
                color: primaryColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Header ────────────────────────────────────────────────────

  pw.Widget _buildHeader(
    pw.Context ctx,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor headerBg,
    PdfColor textDark,
    String generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(color: headerBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MCP Avadi',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Madras City Properties – Avadi Branch',
                    style: pw.TextStyle(
                      color: goldColor,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Customer Report',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Generated: $generatedAt',
                    style: pw.TextStyle(
                      color: goldColor,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  // ─── Summary cards row ─────────────────────────────────────────

  pw.Widget _buildSummaryRow(
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor textMuted,
  ) {
    return pw.Row(
      children: [
        _summaryCard('Total Customers', '$totalCustomers', primaryColor),
        pw.SizedBox(width: 8),
        _summaryCard('Booked', '$bookedCustomers', PdfColor.fromInt(0xFF15803D)),
        pw.SizedBox(width: 8),
        _summaryCard('Reg. Completed', '$registrationCompleted',
            PdfColor.fromInt(0xFF1E40AF)),
        pw.SizedBox(width: 8),
        _summaryCard('Pending',
            '${totalCustomers - bookedCustomers}', goldColor),
      ],
    );
  }

  pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Footer ────────────────────────────────────────────────────

  pw.Widget _buildFooter(
    pw.Context ctx,
    PdfColor primaryColor,
    PdfColor textMuted,
    String generatedAt,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: primaryColor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MCP Avadi CRM – Madras City Properties, Avadi Branch',
              style: pw.TextStyle(color: textMuted, fontSize: 7),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(color: textMuted, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Table cell helpers ────────────────────────────────────────

  pw.Widget _cell(String text, PdfColor color, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: color, fontSize: fontSize),
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _tagCell(String text, PdfColor bg, PdfColor textColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: textColor,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
