/**
 * Invoice Processor — PDF Text Extraction
 *
 * Primary: pdftotext -layout (poppler) — preserves table structure
 * Fallback: tesseract OCR — for scanned PDFs with minimal extractable text
 */

/**
 * Extract text from a PDF file.
 * Uses pdftotext first; falls back to tesseract if result is too short.
 */
export async function extractText(pdfPath: string): Promise<string> {
  const text = await pdftotextExtract(pdfPath);

  // If pdftotext returned meaningful content, use it
  const nonWhitespace = text.replace(/\s/g, "").length;
  if (nonWhitespace >= 50) {
    return text;
  }

  // Scanned PDF — try OCR
  console.log(
    `[invoice] pdftotext returned ${nonWhitespace} chars, falling back to tesseract`
  );
  return tesseractExtract(pdfPath);
}

/**
 * Extract text using poppler's pdftotext with -layout flag.
 * -layout preserves the spatial arrangement of text on the page,
 * which is critical for parsing tabular invoice data.
 */
async function pdftotextExtract(pdfPath: string): Promise<string> {
  const proc = Bun.spawn(["pdftotext", "-layout", pdfPath, "-"], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    console.error(`[invoice] pdftotext failed (exit ${exitCode}): ${stderr}`);
    return "";
  }

  return stdout;
}

/**
 * Extract text using tesseract OCR.
 * Converts PDF pages to images first (via pdftoppm), then runs OCR.
 */
async function tesseractExtract(pdfPath: string): Promise<string> {
  // pdftoppm converts PDF → PNG images that tesseract can read
  const tmpDir = `/tmp/invoice-ocr-${Date.now()}`;
  const mkdirProc = Bun.spawn(["mkdir", "-p", tmpDir], { stdout: "pipe" });
  await mkdirProc.exited;

  try {
    // Convert PDF to PNG images
    const ppmProc = Bun.spawn(
      ["pdftoppm", "-png", "-r", "300", pdfPath, `${tmpDir}/page`],
      { stdout: "pipe", stderr: "pipe" }
    );
    const ppmStderr = await new Response(ppmProc.stderr).text();
    const ppmExit = await ppmProc.exited;

    if (ppmExit !== 0) {
      console.error(`[invoice] pdftoppm failed: ${ppmStderr}`);
      return "";
    }

    // Find generated page images
    const lsProc = Bun.spawn(["ls", tmpDir], { stdout: "pipe" });
    const files = (await new Response(lsProc.stdout).text())
      .trim()
      .split("\n")
      .filter((f) => f.endsWith(".png"))
      .sort();

    if (files.length === 0) {
      console.error("[invoice] pdftoppm produced no images");
      return "";
    }

    // Run tesseract on each page and concatenate
    const pages: string[] = [];
    for (const file of files) {
      const ocrProc = Bun.spawn(
        ["tesseract", `${tmpDir}/${file}`, "stdout", "--psm", "6"],
        { stdout: "pipe", stderr: "pipe" }
      );
      const ocrText = await new Response(ocrProc.stdout).text();
      await ocrProc.exited;
      pages.push(ocrText);
    }

    return pages.join("\n--- PAGE BREAK ---\n");
  } finally {
    // Cleanup temp files
    Bun.spawn(["rm", "-rf", tmpDir], { stdout: "pipe" });
  }
}
