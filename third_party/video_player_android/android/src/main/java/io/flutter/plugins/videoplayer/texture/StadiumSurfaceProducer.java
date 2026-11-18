// Local Highlanders renderer extension.
package io.flutter.plugins.videoplayer.texture;

import android.view.Surface;
import androidx.annotation.Nullable;
import io.flutter.view.TextureRegistry;

/** Uses the engine's SurfaceTexture crop matrix for the bundled stadium video. */
public final class StadiumSurfaceProducer implements TextureRegistry.SurfaceProducer {
  private final TextureRegistry.SurfaceTextureEntry entry;
  private Surface surface;
  @Nullable private Callback callback;
  private int width = 1;
  private int height = 1;
  private boolean released = false;

  public StadiumSurfaceProducer(TextureRegistry.SurfaceTextureEntry entry) {
    this.entry = entry;
    surface = new Surface(entry.surfaceTexture());
  }

  @Override
  public long id() { return entry.id(); }

  @Override
  public Surface getSurface() { return surface; }

  @Override
  public Surface getForcedNewSurface() {
    if (callback != null) callback.onSurfaceCleanup();
    surface.release();
    surface = new Surface(entry.surfaceTexture());
    if (callback != null) callback.onSurfaceAvailable();
    return surface;
  }

  @Override
  public void setSize(int width, int height) {
    this.width = Math.max(1, width);
    this.height = Math.max(1, height);
    entry.surfaceTexture().setDefaultBufferSize(this.width, this.height);
  }

  @Override
  public int getWidth() { return width; }

  @Override
  public int getHeight() { return height; }

  @Override
  public void setCallback(@Nullable Callback callback) { this.callback = callback; }

  @Override
  public boolean handlesCropAndRotation() { return true; }

  @Override
  public void scheduleFrame() {
    // SurfaceTexture frame-available notifications are driven by the engine.
  }

  @Override
  public void release() {
    if (released) return;
    released = true;
    callback = null;
    surface.release();
    entry.release();
  }
}
