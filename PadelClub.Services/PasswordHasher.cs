using System;
using System.Security.Cryptography;
using System.Text;

namespace PadelClub.Services
{
    /// <summary>
    /// PBKDF2-based password hasher implementation using <see cref="Rfc2898DeriveBytes"/>.
    /// The stored hash format is: {iterations}.{base64(salt)}.{base64(derivedKey)}.
    /// </summary>
    public class PasswordHasher : IPasswordHasher
    {
        // PBKDF2 configuration
        private const int SaltSize = 16;        // 128-bit salt
        private const int KeySize = 32;         // 256-bit subkey
        private const int Iterations = 100_000; // Reasonable default for 2024+

        /// <summary>
        /// Hashes a plain text password using PBKDF2 (Rfc2898DeriveBytes with SHA256).
        /// </summary>
        /// <param name="password">The plain text password to hash.</param>
        /// <returns>
        /// String in the form: "{iterations}.{base64(salt)}.{base64(derivedKey)}".
        /// </returns>
        public string HashPassword(string password)
        {
            if (string.IsNullOrWhiteSpace(password))
                throw new ArgumentException("Password cannot be null or empty.", nameof(password));

            // Generate a random salt
            var salt = new byte[SaltSize];
            RandomNumberGenerator.Fill(salt);

            // Derive a key from the password and salt
            using var pbkdf2 = new Rfc2898DeriveBytes(
                password,
                salt,
                Iterations,
                HashAlgorithmName.SHA256);

            var key = pbkdf2.GetBytes(KeySize);

            var saltBase64 = Convert.ToBase64String(salt);
            var keyBase64 = Convert.ToBase64String(key);

            return $"{Iterations}.{saltBase64}.{keyBase64}";
        }

        /// <summary>
        /// Verifies a plain text password against a PBKDF2 hash.
        /// </summary>
        /// <param name="password">The plain text password to verify.</param>
        /// <param name="hashedPassword">The stored hash string.</param>
        /// <returns>True if the password matches the hash, false otherwise.</returns>
        public bool VerifyPassword(string password, string hashedPassword)
        {
            if (string.IsNullOrWhiteSpace(password))
                return false;

            if (string.IsNullOrWhiteSpace(hashedPassword))
                return false;

            try
            {
                var parts = hashedPassword.Split('.');
                if (parts.Length != 3)
                    return false;

                if (!int.TryParse(parts[0], out var iterations))
                    return false;

                var salt = Convert.FromBase64String(parts[1]);
                var expectedKey = Convert.FromBase64String(parts[2]);

                using var pbkdf2 = new Rfc2898DeriveBytes(
                    password,
                    salt,
                    iterations,
                    HashAlgorithmName.SHA256);

                var actualKey = pbkdf2.GetBytes(expectedKey.Length);

                return AreHashesEqual(actualKey, expectedKey);
            }
            catch
            {
                // Invalid format or other error
                return false;
            }
        }

        private static bool AreHashesEqual(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length)
                return false;

            var result = 0;
            for (int i = 0; i < a.Length; i++)
            {
                result |= a[i] ^ b[i];
            }

            return result == 0;
        }
    }
}




