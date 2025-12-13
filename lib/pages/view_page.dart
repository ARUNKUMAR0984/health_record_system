import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../services/encryption_service.dart';

// UI COLOR CONSTANTS
const Color primaryColor = Color(0xFF00B4DB);
const Color primaryDark = Color(0xFF0083B0);
const Color secondaryColor = Color(0xFF10B981);
const Color backgroundColor = Color(0xFFF5F7FA);
const Color cardColor = Colors.white;
const Color errorColor = Color(0xFFEF4444);
const Color warningColor = Color(0xFFF59E0B);
const Color textPrimary = Color(0xFF1A1F36);
const Color textSecondary = Color(0xFF6B7280);

class ViewFilePage extends StatefulWidget {
  final Map<String, dynamic> block;

  const ViewFilePage({super.key, required this.block});

  @override
  State<ViewFilePage> createState() => _ViewFilePageState();
}

class _ViewFilePageState extends State<ViewFilePage> with SingleTickerProviderStateMixin {
  Uint8List? decryptedBytes;
  File? pdfFile;
  bool loading = true;
  bool decryptFailed = false;
  
  // PDF viewer controller
  final PdfViewerController _pdfController = PdfViewerController();
  
  // UI state
  bool _showControls = true;
  bool _showMetadata = false;
  double _currentZoom = 1.0;
  int _currentPage = 1;
  int _totalPages = 0;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    loadAndDecrypt();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadAndDecrypt() async {
    try {
      final url = widget.block["file_url"];
      final keyB64 = widget.block["key_base64"];
      final ivB64 = widget.block["iv"];

      if (keyB64 == null || ivB64 == null) {
        setState(() {
          decryptFailed = true;
          loading = false;
        });
        return;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        setState(() {
          decryptFailed = true;
          loading = false;
        });
        return;
      }

      final cipherBytes = response.bodyBytes;
      final plainBytes = EncryptionService.decryptBytes(cipherBytes, keyB64, ivB64);

      final isPdf = (widget.block["file_url"] as String).contains(".pdf");

      if (isPdf) {
        final dir = await getTemporaryDirectory();
        final filePath =
            "${dir.path}/decrypted_${DateTime.now().millisecondsSinceEpoch}.pdf";

        pdfFile = File(filePath);
        await pdfFile!.writeAsBytes(plainBytes);
      } else {
        decryptedBytes = Uint8List.fromList(plainBytes);
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint("❌ Decrypt error: $e");
      setState(() {
        decryptFailed = true;
        loading = false;
      });
    }
  }

  bool get isPdf => (widget.block["file_url"] as String).contains(".pdf");
  String get fileName => (widget.block["file_url"] as String).split("/").last;
  
  String get fileSize {
    final bytes = decryptedBytes?.length ?? pdfFile?.lengthSync() ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_showMetadata && !loading && !decryptFailed)
              _buildMetadataPanel(),
            Expanded(
              child: Stack(
                children: [
                  _buildMainContent(),
                  if (isPdf && !loading && !decryptFailed)
                    _buildPdfControls(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (!loading && !decryptFailed)
          ? _buildFloatingActions()
          : null,
    );
  }

  // ---------------------------------------------------------------------
  // CUSTOM APP BAR
  // ---------------------------------------------------------------------
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: textPrimary),
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!loading)
                  Text(
                    fileSize,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _showMetadata = !_showMetadata);
            },
            icon: Icon(
              _showMetadata ? Icons.info : Icons.info_outline,
              color: _showMetadata ? primaryColor : textSecondary,
            ),
            tooltip: 'Document Info',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: textSecondary),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_hash',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, size: 20),
                    SizedBox(width: 12),
                    Text('Copy Block Hash'),
                  ],
                ),
              ),
              if (isPdf) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print, size: 20),
                      SizedBox(width: 12),
                      Text('Print'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // METADATA PANEL
  // ---------------------------------------------------------------------
  Widget _buildMetadataPanel() {
    final hash = widget.block["current_hash"] ?? "N/A";
    final previousHash = widget.block["previous_hash"] ?? "Genesis Block";
    final timestamp = widget.block["created_at"];
    final isVerified = widget.block["doctor_signature"] != null;

    String formattedDate = "N/A";
    if (timestamp != null) {
      try {
        final date = DateTime.parse(timestamp);
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      } catch (_) {}
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Document Metadata",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetadataRow(
              Icons.check_circle,
              "Verification Status",
              isVerified ? "Verified & Signed" : "Unverified",
              isVerified ? secondaryColor : errorColor,
            ),
            const Divider(height: 24),
            _buildMetadataRow(
              Icons.access_time,
              "Added On",
              formattedDate,
              textSecondary,
            ),
            const Divider(height: 24),
            _buildMetadataRow(
              Icons.tag,
              "Block Hash",
              "${hash.substring(0, 16)}...",
              textSecondary,
              onTap: () => _copyToClipboard(hash, "Block hash copied"),
            ),
            const Divider(height: 24),
            _buildMetadataRow(
              Icons.link,
              "Previous Hash",
              previousHash == "Genesis Block" 
                  ? previousHash 
                  : "${previousHash.substring(0, 16)}...",
              textSecondary,
            ),
            if (isPdf && _totalPages > 0) ...[
              const Divider(height: 24),
              _buildMetadataRow(
                Icons.picture_as_pdf,
                "Pages",
                "$_totalPages pages",
                textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.content_copy, size: 16, color: textSecondary),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MAIN CONTENT
  // ---------------------------------------------------------------------
  Widget _buildMainContent() {
    if (loading) {
      return _buildLoadingState();
    }

    if (decryptFailed) {
      return _buildErrorState();
    }

    return Container(
      color: isPdf ? const Color(0xFFE5E7EB) : cardColor,
      child: isPdf ? _buildSyncfusionPdfViewer() : _buildImageViewer(),
    );
  }

  // ---------------------------------------------------------------------
  // LOADING STATE
  // ---------------------------------------------------------------------
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Decrypting Document",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please wait while we securely decrypt your file",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 64,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Decryption Failed",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Unable to decrypt this document. The encryption keys may be missing or invalid.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Go Back"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // IMAGE VIEWER
  // ---------------------------------------------------------------------
  Widget _buildImageViewer() {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            decryptedBytes!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: errorColor),
                  const SizedBox(height: 16),
                  const Text(
                    "Unable to display image",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "The file format may not be supported",
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // PDF VIEWER
  // ---------------------------------------------------------------------
  Widget _buildSyncfusionPdfViewer() {
    if (pdfFile == null) {
      return const Center(child: Text("Failed to open decrypted PDF"));
    }

    return SfPdfViewer.file(
      pdfFile!,
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableTextSelection: true,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _totalPages = details.document.pages.count;
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
    );
  }

  // ---------------------------------------------------------------------
  // PDF CONTROLS OVERLAY
  // ---------------------------------------------------------------------
  Widget _buildPdfControls() {
    if (!_showControls || _totalPages == 0) return const SizedBox();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: textPrimary.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  if (_currentPage > 1) {
                    _pdfController.previousPage();
                  }
                },
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _currentPage > 1 ? Colors.white : Colors.white38,
                  size: 20,
                ),
              ),
              Text(
                "$_currentPage / $_totalPages",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_currentPage < _totalPages) {
                    _pdfController.nextPage();
                  }
                },
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _currentPage < _totalPages ? Colors.white : Colors.white38,
                  size: 20,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white24,
              ),
              IconButton(
                onPressed: () {
                  _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(0.5, 3.0);
                },
                icon: const Icon(Icons.zoom_in, color: Colors.white, size: 22),
                tooltip: 'Zoom In',
              ),
              IconButton(
                onPressed: () {
                  _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(0.5, 3.0);
                },
                icon: const Icon(Icons.zoom_out, color: Colors.white, size: 22),
                tooltip: 'Zoom Out',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FLOATING ACTION BUTTONS
  // ---------------------------------------------------------------------
  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPdf)
          FloatingActionButton(
            heroTag: 'search',
            onPressed: () {
              _pdfController.searchText('search_term');
              _showSnackBar("Search feature - Enter your search term");
            },
            backgroundColor: cardColor,
            child: const Icon(Icons.search, color: primaryColor),
          ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'download',
          onPressed: _handleDownload,
          backgroundColor: primaryColor,
          child: const Icon(Icons.download, color: Colors.white),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------
  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _handleShare();
        break;
      case 'copy_hash':
        final hash = widget.block["current_hash"] ?? "";
        _copyToClipboard(hash, "Block hash copied to clipboard");
        break;
      case 'print':
        _showSnackBar("Print feature - Coming soon");
        break;
    }
  }

  Future<void> _handleShare() async {
    if (pdfFile != null) {
      await Share.shareXFiles([XFile(pdfFile!.path)], text: 'Sharing medical document');
    } else if (decryptedBytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shared_image.jpg');
      await file.writeAsBytes(decryptedBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'Sharing medical image');
    }
  }

  void _handleDownload() {
    _showSnackBar("Download started - File will be saved to your device");
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: textPrimary,
      ),
    );
  }
}