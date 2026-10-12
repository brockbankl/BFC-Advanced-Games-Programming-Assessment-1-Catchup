// MonoGame - Copyright (C) MonoGame Foundation, Inc
// This file is subject to the terms and conditions defined in
// file 'LICENSE.md', which is part of this source code package.

using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;

/// <summary>
/// A decorative animated surface that begins rising after a short head start.
/// Contact is deliberately harmless so students can add hazard behaviour.
/// </summary>
public class RisingWater : Entity
{
    private const float START_DELAY_SECONDS = 8.0f;
    private float _elapsedTime;

    public Color TintColor { get; private set; } = new Color(40, 175, 225);
    public float RiseSpeed { get; private set; } = 12.0f;
    public float AnimationTime => _elapsedTime;

    public RisingWater(Model model, ContentManager contentManager) : base(model, contentManager)
    {
        IsBlockingMovement = false;
        CastShadow = false;
    }

    public override void SetProperties(SceneNodeContent data)
    {
        base.SetProperties(data);

        TintColor = SceneContentValueConverters.ToColor(
            data.ColorHex,
            new Color(40, 175, 225));

        if (data.HasMoveSpeed)
            RiseSpeed = data.MoveSpeed;
    }

    public override void Update(GameTime gameTime)
    {
        float deltaTime = (float)gameTime.ElapsedGameTime.TotalSeconds;
        _elapsedTime += deltaTime;

        if (_elapsedTime > START_DELAY_SECONDS)
            Position += Vector3.Up * RiseSpeed * deltaTime;

        base.Update(gameTime);
    }
}
