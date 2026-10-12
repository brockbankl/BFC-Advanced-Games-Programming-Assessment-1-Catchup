using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;

/// <summary>
/// The two simple weather styles supported by the teaching example.
/// </summary>
public enum WeatherParticleMode
{
    Snow,
    Rain
}

/// <summary>
/// Editable values that control how a weather particle system behaves.
/// Keeping these values together makes experimentation easier for students.
/// </summary>
public sealed class WeatherParticleSettings
{
    public WeatherParticleMode Mode { get; set; } = WeatherParticleMode.Snow;
    public int Capacity { get; set; } = 400;
    public float ParticlesPerSecond { get; set; } = 120f;
    public float HorizontalRadius { get; set; } = 650f;
    // Keep the default band below the camera's usual height so new weather is
    // visible while the camera looks down towards the player.
    public float SpawnHeight { get; set; } = 250f;
    public float DespawnDepth { get; set; } = 250f;
    public Vector3 Wind { get; set; } = new Vector3(18f, 0f, 6f);

    public float MinimumSnowSpeed { get; set; } = 45f;
    public float MaximumSnowSpeed { get; set; } = 90f;
    public float SnowDriftStrength { get; set; } = 22f;
    public Vector2 SnowScale { get; set; } = new Vector2(0.18f, 0.18f);
    public Color SnowColor { get; set; } = new Color(235, 245, 255, 220);

    public float MinimumRainSpeed { get; set; } = 550f;
    public float MaximumRainSpeed { get; set; } = 800f;
    public Vector2 RainScale { get; set; } = new Vector2(0.035f, 0.5f);
    public Color RainColor { get; set; } = new Color(170, 205, 235, 155);

    public static WeatherParticleSettings CreateSnow()
    {
        return new WeatherParticleSettings();
    }

    public static WeatherParticleSettings CreateRain()
    {
        return new WeatherParticleSettings
        {
            Mode = WeatherParticleMode.Rain,
            Capacity = 550,
            ParticlesPerSecond = 220f,
            Wind = new Vector3(65f, 0f, 10f)
        };
    }

    internal void Validate()
    {
        if (Capacity <= 0)
            throw new ArgumentOutOfRangeException(nameof(Capacity), "Capacity must be greater than zero.");
        if (ParticlesPerSecond < 0f)
            throw new ArgumentOutOfRangeException(nameof(ParticlesPerSecond), "Spawn rate cannot be negative.");
        if (HorizontalRadius <= 0f || SpawnHeight <= 0f || DespawnDepth <= 0f)
            throw new ArgumentOutOfRangeException(nameof(HorizontalRadius), "Weather volume dimensions must be positive.");
        if (MinimumSnowSpeed <= 0f || MaximumSnowSpeed < MinimumSnowSpeed)
            throw new ArgumentOutOfRangeException(nameof(MinimumSnowSpeed), "Snow speed range is invalid.");
        if (MinimumRainSpeed <= 0f || MaximumRainSpeed < MinimumRainSpeed)
            throw new ArgumentOutOfRangeException(nameof(MinimumRainSpeed), "Rain speed range is invalid.");
    }
}

/// <summary>
/// A small, allocation-free weather particle pool that follows a world-space centre point.
/// Particles are projected into screen space and drawn as camera-facing sprites.
/// </summary>
public sealed class WeatherParticleSystem
{
    private struct WeatherParticle
    {
        public bool Active;
        public Vector3 Position;
        public Vector3 Velocity;
        public float Age;
        public float Rotation;
        public float RotationSpeed;
        public float DriftPhase;
        public float DriftFrequency;
        public float SizeMultiplier;
    }

    private readonly WeatherParticleSettings _settings;
    private readonly WeatherParticle[] _particles;
    private readonly Texture2D _texture;
    private readonly Random _random;
    private float _spawnAccumulator;

    public bool Enabled { get; set; } = true;
    public int ActiveCount { get; private set; }
    public int VisibleCount { get; private set; }
    public WeatherParticleMode Mode => _settings.Mode;
    public WeatherParticleSettings Settings => _settings;

    public WeatherParticleSystem(
        ContentManager content,
        WeatherParticleSettings settings,
        int randomSeed = 1977)
    {
        _settings = settings ?? throw new ArgumentNullException(nameof(settings));
        _settings.Validate();

        _particles = new WeatherParticle[_settings.Capacity];
        _texture = content.Load<Texture2D>("Textures/particle");
        _random = new Random(randomSeed);
    }

    /// <summary>
    /// Advances the simulation and keeps the weather volume centred on the supplied position.
    /// </summary>
    public void Update(GameTime gameTime, Vector3 centre)
    {
        if (!Enabled)
            return;

        // A large delta after a breakpoint can otherwise move every particle out of the volume.
        float deltaTime = MathF.Min((float)gameTime.ElapsedGameTime.TotalSeconds, 0.05f);
        SpawnParticles(deltaTime, centre);

        float maximumDistance = _settings.HorizontalRadius * 1.35f;
        float maximumDistanceSquared = maximumDistance * maximumDistance;

        for (int i = 0; i < _particles.Length; i++)
        {
            if (!_particles[i].Active)
                continue;

            ref WeatherParticle particle = ref _particles[i];
            particle.Age += deltaTime;

            Vector3 movement = particle.Velocity;
            if (_settings.Mode == WeatherParticleMode.Snow)
            {
                float drift = MathF.Sin(particle.DriftPhase + particle.Age * particle.DriftFrequency);
                movement.X += drift * _settings.SnowDriftStrength;
                movement.Z += MathF.Cos(particle.DriftPhase + particle.Age) * _settings.SnowDriftStrength * 0.35f;
                particle.Rotation += particle.RotationSpeed * deltaTime;
            }

            particle.Position += movement * deltaTime;

            Vector2 horizontalOffset = new Vector2(
                particle.Position.X - centre.X,
                particle.Position.Z - centre.Z);

            bool belowWeatherVolume = particle.Position.Y < centre.Y - _settings.DespawnDepth;
            bool outsideWeatherVolume = horizontalOffset.LengthSquared() > maximumDistanceSquared;

            if (belowWeatherVolume || outsideWeatherVolume)
                RecycleParticle(i, centre);
        }
    }

    /// <summary>
    /// Draws particles inside an existing SpriteBatch Begin/End block.
    /// </summary>
    public void Draw(GraphicsDevice graphicsDevice, SpriteBatch spriteBatch, Camera camera)
    {
        VisibleCount = 0;

        if (!Enabled || ActiveCount == 0)
            return;

        Viewport viewport = graphicsDevice.Viewport;
        Vector2 origin = new Vector2(_texture.Width * 0.5f, _texture.Height * 0.5f);

        for (int i = 0; i < _particles.Length; i++)
        {
            WeatherParticle particle = _particles[i];
            if (!particle.Active)
                continue;

            Vector3 screenPosition = viewport.Project(
                particle.Position,
                camera.ProjectionMatrix,
                camera.ViewMatrix,
                Matrix.Identity);

            if (screenPosition.Z <= 0f || screenPosition.Z >= 1f)
                continue;
            if (screenPosition.X < -64f || screenPosition.X > viewport.Width + 64f)
                continue;
            if (screenPosition.Y < -64f || screenPosition.Y > viewport.Height + 64f)
                continue;

            VisibleCount++;

            bool isSnow = _settings.Mode == WeatherParticleMode.Snow;
            Vector2 baseScale = isSnow ? _settings.SnowScale : _settings.RainScale;
            Color color = isSnow ? _settings.SnowColor : _settings.RainColor;

            // Nearby flakes/drops are slightly larger, which gives a simple depth cue.
            float depthScale = MathHelper.Lerp(1.2f, 0.6f, screenPosition.Z);
            Vector2 scale = baseScale * particle.SizeMultiplier * depthScale;

            spriteBatch.Draw(
                _texture,
                new Vector2(screenPosition.X, screenPosition.Y),
                null,
                color,
                particle.Rotation,
                origin,
                scale,
                SpriteEffects.None,
                screenPosition.Z);
        }
    }

    public void Clear()
    {
        Array.Clear(_particles, 0, _particles.Length);
        ActiveCount = 0;
        _spawnAccumulator = 0f;
    }

    private void SpawnParticles(float deltaTime, Vector3 centre)
    {
        _spawnAccumulator += _settings.ParticlesPerSecond * deltaTime;
        int particlesToSpawn = (int)_spawnAccumulator;
        _spawnAccumulator -= particlesToSpawn;

        for (int i = 0; i < particlesToSpawn; i++)
        {
            int freeIndex = FindFreeParticle();
            if (freeIndex < 0)
                return;

            ActivateParticle(freeIndex, centre);
        }
    }

    private int FindFreeParticle()
    {
        for (int i = 0; i < _particles.Length; i++)
        {
            if (!_particles[i].Active)
                return i;
        }

        return -1;
    }

    private void RecycleParticle(int index, Vector3 centre)
    {
        ActivateParticle(index, centre);
    }

    private void ActivateParticle(int index, Vector3 centre)
    {
        bool wasActive = _particles[index].Active;
        float x = RandomRange(-_settings.HorizontalRadius, _settings.HorizontalRadius);
        float z = RandomRange(-_settings.HorizontalRadius, _settings.HorizontalRadius);
        float y = RandomRange(_settings.SpawnHeight * 0.55f, _settings.SpawnHeight);
        bool isSnow = _settings.Mode == WeatherParticleMode.Snow;

        float fallSpeed = isSnow
            ? RandomRange(_settings.MinimumSnowSpeed, _settings.MaximumSnowSpeed)
            : RandomRange(_settings.MinimumRainSpeed, _settings.MaximumRainSpeed);

        Vector3 randomWind = isSnow
            ? new Vector3(RandomRange(-8f, 8f), 0f, RandomRange(-8f, 8f))
            : Vector3.Zero;

        _particles[index] = new WeatherParticle
        {
            Active = true,
            Position = centre + new Vector3(x, y, z),
            Velocity = _settings.Wind + randomWind + new Vector3(0f, -fallSpeed, 0f),
            Age = 0f,
            Rotation = isSnow ? RandomRange(0f, MathHelper.TwoPi) : RainRotation(),
            RotationSpeed = isSnow ? RandomRange(-1.5f, 1.5f) : 0f,
            DriftPhase = RandomRange(0f, MathHelper.TwoPi),
            DriftFrequency = RandomRange(0.8f, 2.2f),
            SizeMultiplier = RandomRange(0.65f, 1.35f)
        };

        if (!wasActive)
            ActiveCount++;
    }

    private float RainRotation()
    {
        // SpriteBatch's zero rotation points down the texture's Y axis.
        return MathF.Atan2(_settings.Wind.X, _settings.MaximumRainSpeed);
    }

    private float RandomRange(float minimum, float maximum)
    {
        return minimum + _random.NextSingle() * (maximum - minimum);
    }
}
