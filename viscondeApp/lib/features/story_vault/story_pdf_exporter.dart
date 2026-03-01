import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../story_room/models/story_models.dart';
import 'book_models.dart';

class StoryPdfExporter {
  static Future<void> exportAndShare(StorySessionModel story) async {
    final pdf = pw.Document();

    // Capa
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  story.title,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Uma aventura de ${story.child.name}!',
                  style: const pw.TextStyle(fontSize: 24),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Timeline Paginas
    for (final step in story.steps) {
      if (step.narratorText != null && step.narratorText!.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Capitulo ${step.stepIndex}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Em uma versao mais avancada, poderiamos baixar a url da imagem (StoryIllustration)
                  // e injetar na arvore do pw.Image aqui!
                  pw.Text(
                    step.narratorText!,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // Compartilhar Nativo
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Visconde_${story.title.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> exportBookProject(BookProjectModel book) async {
    final pdf = pw.Document();

    // Capa do Livro
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  book.title,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Coletânea de aventuras',
                  style: const pw.TextStyle(fontSize: 24),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Periodo: ${book.month}',
                  style: const pw.TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Iterar pelas Historias
    for (final story in book.stories) {
      // Contra-capa da historia
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    story.title,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 20),
                  if (story.virtue != null)
                    pw.Text(
                      'Virtude: ${story.virtue!.name}',
                      style: const pw.TextStyle(fontSize: 20),
                    ),
                ],
              ),
            );
          },
        ),
      );

      // Paginas da historia
      for (final step in story.steps) {
        if (step.narratorText != null && step.narratorText!.isNotEmpty) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Capítulo ${step.stepIndex}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      step.narratorText!,
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }
    }

    // Compartilhar Nativo
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Visconde_Livro_${book.month}.pdf',
    );
  }
}
