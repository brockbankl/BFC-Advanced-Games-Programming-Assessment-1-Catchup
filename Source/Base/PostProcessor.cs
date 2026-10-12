// MonoGame - Copyright (C) MonoGame Foundation, Inc
// This file is subject to the terms and conditions defined in
// file 'LICENSE.md', which is part of this source code package.

using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

/// <summary>
/// Handles post-processing effects like bloom, vignette and posterisation.
/// This class is fairly self contained. It does however
/// require the relevant shaders to be present in Content/Assets/Effects.
/// </summary>
public class PostProcessor
{
    private GraphicsDevice _graphicsDevice;
    private RenderTarget2D _mainRenderTarget;
    private RenderTarget2D _bloomExtractTarget;
    private RenderTarget2D _bloomBlurTarget1;
    private RenderTarget2D _bloomBlurTarget2;
    private RenderTarget2D _postProcessTarget;

    private Effect _bloomEffect;
    private Effect _vignetteEffect;
    private Effect _posterizeEffect;
    private SpriteBatch _spriteBatch;

    public bool BloomEnabled { get; set; }
    public bool VignetteEnabled { get; set; }

    // Week 3 addition: leave the existing appearance unchanged until enabled.
    public bool PosterizeEnabled { get; set; } = false;

    // Number of colour levels per RGB channel. Try 2, 4 and 8.
    public float PosterizeLevels { get; set; } = 4f;

    public PostProcessor(GraphicsDevice graphicsDevice, SpriteBatch spriteBatch)
    {
        _graphicsDevice = graphicsDevice;
        _spriteBatch = spriteBatch;
        CreateRenderTargets();

        BloomEnabled = true;
        VignetteEnabled = true;
    }

    private void CreateRenderTargets()
    {
        var hdrFormat = SurfaceFormat.HdrBlendable;

        // Store the combined image only when the final posterisation pass is used.
        _postProcessTarget = new RenderTarget2D(
            _graphicsDevice,
            _graphicsDevice.PresentationParameters.BackBufferWidth,
            _graphicsDevice.PresentationParameters.BackBufferHeight,
            false,
            SurfaceFormat.Color,
            DepthFormat.None);

        _mainRenderTarget = new RenderTarget2D(
            _graphicsDevice,
            _graphicsDevice.PresentationParameters.BackBufferWidth,
            _graphicsDevice.PresentationParameters.BackBufferHeight,
            false,
            hdrFormat,
            DepthFormat.Depth24);

        _bloomExtractTarget = new RenderTarget2D(
            _graphicsDevice,
            _graphicsDevice.PresentationParameters.BackBufferWidth,
            _graphicsDevice.PresentationParameters.BackBufferHeight,
            false,
            hdrFormat,
            DepthFormat.None);

        _bloomBlurTarget1 = new RenderTarget2D(
            _graphicsDevice,
            _graphicsDevice.PresentationParameters.BackBufferWidth / 2,
            _graphicsDevice.PresentationParameters.BackBufferHeight / 2,
            false,
            hdrFormat,
            DepthFormat.None);

        _bloomBlurTarget2 = new RenderTarget2D(
            _graphicsDevice,
            _graphicsDevice.PresentationParameters.BackBufferWidth / 4,
            _graphicsDevice.PresentationParameters.BackBufferHeight / 4,
            false,
            hdrFormat,
            DepthFormat.None);
    }

    public void LoadContent(Microsoft.Xna.Framework.Content.ContentManager content)
    {
        _bloomEffect = content.Load<Effect>("Effects/BloomEffect");
        _vignetteEffect = content.Load<Effect>("Effects/VignetteEffect");
        _posterizeEffect = content.Load<Effect>("Effects/PosterizeEffect");
    }

    public void BeginScene()
    {
        _graphicsDevice.SetRenderTarget(_mainRenderTarget);
    }

    public void EndScene()
    {
        _graphicsDevice.SetRenderTarget(null);
        ApplyPostProcessing();
    }

    private void ApplyPostProcessing()
    {
        if (BloomEnabled)
        {
            // Extract bright areas for bloom.
            _graphicsDevice.SetRenderTarget(_bloomExtractTarget);
            _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.Opaque);
            _bloomEffect.CurrentTechnique = _bloomEffect.Techniques["BloomExtract"];
            _bloomEffect.Parameters["BloomThreshold"].SetValue(1.2f);
            _bloomEffect.CurrentTechnique.Passes[0].Apply();
            _spriteBatch.Draw(_mainRenderTarget, _bloomExtractTarget.Bounds, Color.White);
            _spriteBatch.End();

            // Blur horizontally.
            _graphicsDevice.SetRenderTarget(_bloomBlurTarget1);
            _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.Opaque);
            _bloomEffect.CurrentTechnique = _bloomEffect.Techniques["GaussianBlur"];
            _bloomEffect.Parameters["TexelSize"].SetValue(2.0f / _bloomBlurTarget1.Width);
            _bloomEffect.Parameters["Direction"].SetValue(new Vector2(1, 0));
            _bloomEffect.CurrentTechnique.Passes[0].Apply();
            _spriteBatch.Draw(_bloomExtractTarget, _bloomBlurTarget1.Bounds, Color.White);
            _spriteBatch.End();

            // Blur vertically.
            _graphicsDevice.SetRenderTarget(_bloomBlurTarget2);
            _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.Opaque);
            _bloomEffect.CurrentTechnique = _bloomEffect.Techniques["GaussianBlur"];
            _bloomEffect.Parameters["TexelSize"].SetValue(2.0f / _bloomBlurTarget2.Width);
            _bloomEffect.Parameters["Direction"].SetValue(new Vector2(0, 1));
            _bloomEffect.CurrentTechnique.Passes[0].Apply();
            _spriteBatch.Draw(_bloomBlurTarget1, _bloomBlurTarget2.Bounds, Color.White);
            _spriteBatch.End();

            _graphicsDevice.SetRenderTarget(null);
        }

        // Combine bloom, then overlay vignette. Posterisation needs their finished image.
        _graphicsDevice.SetRenderTarget(PosterizeEnabled ? _postProcessTarget : null);
        var fullscreen = _graphicsDevice.Viewport.Bounds;
        _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.Opaque);
        _bloomEffect.CurrentTechnique = _bloomEffect.Techniques["Combine"];
        _bloomEffect.Parameters["BaseIntensity"].SetValue(1.0f);
        _bloomEffect.Parameters["BloomIntensity"].SetValue(BloomEnabled ? 0.5f : 0.0f);
        _bloomEffect.Parameters["BloomTexture"].SetValue(_bloomBlurTarget2);
        _bloomEffect.CurrentTechnique.Passes[0].Apply();
        _spriteBatch.Draw(_mainRenderTarget, fullscreen, Color.White);
        _spriteBatch.End();

        // Apply vignette.
        if (VignetteEnabled)
        {
            _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.AlphaBlend);
            _vignetteEffect.Parameters["Radius"]?.SetValue(new Vector2(1.0f));
            _vignetteEffect.Parameters["Center"]?.SetValue(new Vector2(0.5f));
            _vignetteEffect.Parameters["Smoothness"]?.SetValue(0.99f);
            _vignetteEffect.CurrentTechnique.Passes[0].Apply();
            _spriteBatch.Draw(_mainRenderTarget, fullscreen, Color.Black * 0.8f);
            _spriteBatch.End();
        }

        // Week 3 addition: reduce colour levels AFTER bloom and vignette.
        // Read from a different target to the one we are drawing into.
        if (PosterizeEnabled)
        {
            _graphicsDevice.SetRenderTarget(null);
            _spriteBatch.Begin(SpriteSortMode.Immediate, BlendState.Opaque);
            _posterizeEffect.Parameters["Levels"].SetValue(MathHelper.Clamp(PosterizeLevels, 2f, 256f));
            _posterizeEffect.CurrentTechnique.Passes[0].Apply();
            _spriteBatch.Draw(_postProcessTarget, fullscreen, Color.White);
            _spriteBatch.End();
        }
    }

    public void DebugDrawRenderTargets(Rectangle rectangle)
    {
        _spriteBatch.Begin();
        //_spriteBatch.Draw(_mainRenderTarget, rectangle, Color.White);
        //_spriteBatch.Draw(_bloomExtractTarget, new Rectangle(rectangle.X + rectangle.Width, rectangle.Y, rectangle.Width, rectangle.Height), Color.White);
        _spriteBatch.Draw(_bloomBlurTarget2, new Rectangle(rectangle.X + (rectangle.Width * 2), rectangle.Y, rectangle.Width, rectangle.Height), Color.White);
        _spriteBatch.End();
    }
}
