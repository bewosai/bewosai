/**
 * Get a picked image ready to upload.
 *
 * Phone cameras produce 5–12 MB photos; the server refuses anything over
 * 5 MB and slow connections make big uploads time out. So an image that's
 * large in bytes or pixels is shrunk (longest side 1600 px, JPEG) in the
 * browser first — still plenty sharp for a bill or receipt. Small images
 * are sent untouched.
 *
 * Throws an Error with a message fit to show the user when the file isn't an
 * image, can't be read, or is still too big after shrinking.
 */
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const SHRINK_ABOVE_BYTES = 1024 * 1024; // leave images under 1 MB alone
const MAX_SIDE = 1600;
const JPEG_QUALITY = 0.82;

const mb = (bytes) => `${(bytes / (1024 * 1024)).toFixed(1)} MB`;

function tooBig(bytes) {
  return new Error(`This image is ${mb(bytes)} — please use one under ${MAX_IMAGE_BYTES / (1024 * 1024)} MB.`);
}

async function decode(file) {
  // imageOrientation keeps phone photos upright instead of sideways.
  if (typeof createImageBitmap === "function") {
    return createImageBitmap(file, { imageOrientation: "from-image" });
  }
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => { URL.revokeObjectURL(url); resolve(img); };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("decode failed")); };
    img.src = url;
  });
}

export async function prepareImage(file) {
  if (!file) return file;
  if (!file.type?.startsWith("image/")) {
    throw new Error("Please choose an image file (JPG or PNG).");
  }
  if (file.size <= SHRINK_ABOVE_BYTES) return file;

  let bitmap;
  try {
    bitmap = await decode(file);
  } catch {
    // Formats the browser can't decode (e.g. HEIC): send as-is if it fits.
    if (file.size <= MAX_IMAGE_BYTES) return file;
    throw new Error("Couldn't read this image. Please choose a JPG or PNG.");
  }

  const width = bitmap.width;
  const height = bitmap.height;
  const scale = Math.min(1, MAX_SIDE / Math.max(width, height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  const ctx = canvas.getContext("2d");
  // JPEG has no transparency — paint white first so a transparent PNG (a logo,
  // a QR code) doesn't turn black.
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close?.();

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY));
  // If shrinking somehow failed or made it bigger, fall back to the original.
  if (!blob || blob.size >= file.size) {
    if (file.size <= MAX_IMAGE_BYTES) return file;
    throw tooBig(file.size);
  }
  if (blob.size > MAX_IMAGE_BYTES) throw tooBig(blob.size);
  const name = file.name.replace(/\.[^.]+$/, "") + ".jpg";
  return new File([blob], name, { type: "image/jpeg", lastModified: Date.now() });
}
