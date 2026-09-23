package ru.itmo.secureapi.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

    private final SecretKey signingKey;
    private final Duration expiration;
    private final String issuer;
    private final Clock clock;

    @Autowired
    public JwtService(
            @Value("${security.jwt.secret}") String base64Secret,
            @Value("${security.jwt.expiration-minutes:15}") long expirationMinutes,
            @Value("${security.jwt.issuer:secure-rest-api}") String issuer
    ) {
        this(Keys.hmacShaKeyFor(io.jsonwebtoken.io.Decoders.BASE64.decode(base64Secret)),
                Duration.ofMinutes(expirationMinutes), issuer, Clock.systemUTC());
    }

    JwtService(SecretKey signingKey, Duration expiration, String issuer, Clock clock) {
        this.signingKey = signingKey;
        this.expiration = expiration;
        this.issuer = issuer;
        this.clock = clock;
    }

    public String generateToken(String username) {
        Instant now = clock.instant();
        return Jwts.builder()
                .subject(username)
                .issuer(issuer)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(expiration)))
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
    }

    public String extractUsername(String token) {
        return parseClaims(token).getSubject();
    }

    public boolean isValid(String token, String expectedUsername) {
        Claims claims = parseClaims(token);
        return expectedUsername.equals(claims.getSubject())
                && claims.getExpiration().toInstant().isAfter(clock.instant());
    }

    public long getExpirationSeconds() {
        return expiration.toSeconds();
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .requireIssuer(issuer)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
