/**
 * Rate Limiter - Brute-force ve DDoS koruması
 * 
 * Endpoint bazlı rate limiting:
 * - Login: 5 deneme / 15 dakika (brute-force koruması)
 * - API: 100 istek / dakika (genel kullanım)
 * - Upload: 10 istek / dakika (dosya yükleme)
 */

import { RateLimiterMemory, RateLimiterRes } from 'rate-limiter-flexible';
import { NextRequest, NextResponse } from 'next/server';

// Rate limiter configurations
const rateLimiters = {
  // Login endpoint - strict limits
  auth: new RateLimiterMemory({
    points: 5,           // 5 attempts
    duration: 60 * 15,   // per 15 minutes
    blockDuration: 60 * 30, // Block for 30 minutes after exceeded
  }),

  // General API endpoints
  api: new RateLimiterMemory({
    points: 100,         // 100 requests
    duration: 60,        // per minute
    blockDuration: 60,   // Block for 1 minute after exceeded
  }),

  // Upload endpoints
  upload: new RateLimiterMemory({
    points: 10,          // 10 uploads
    duration: 60,        // per minute
    blockDuration: 60 * 5, // Block for 5 minutes after exceeded
  }),

  // Password reset - very strict
  passwordReset: new RateLimiterMemory({
    points: 3,           // 3 attempts
    duration: 60 * 60,   // per hour
    blockDuration: 60 * 60, // Block for 1 hour after exceeded
  }),

  // Search/List endpoints - higher limits
  search: new RateLimiterMemory({
    points: 200,         // 200 requests
    duration: 60,        // per minute
    blockDuration: 30,   // Block for 30 seconds
  }),
};

export type RateLimitType = keyof typeof rateLimiters;

/**
 * Get client identifier from request
 * Uses X-Forwarded-For header for proxy support, falls back to IP
 */
function getClientId(req: NextRequest): string {
  // Check for forwarded IP (behind proxy/load balancer)
  const forwardedFor = req.headers.get('x-forwarded-for');
  if (forwardedFor) {
    // Get the first IP in the chain (original client)
    return forwardedFor.split(',')[0].trim();
  }

  // Check for real IP header (Cloudflare, etc.)
  const realIp = req.headers.get('x-real-ip');
  if (realIp) {
    return realIp;
  }

  // Fallback: Use a combination of headers for identification
  const userAgent = req.headers.get('user-agent') || 'unknown';
  return `anonymous-${hashString(userAgent)}`;
}

/**
 * Simple string hash for fallback client identification
 */
function hashString(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash).toString(16);
}

/**
 * Rate limit result interface
 */
export interface RateLimitResult {
  success: boolean;
  limit: number;
  remaining: number;
  resetTime: Date;
  retryAfter?: number;
}

/**
 * Check rate limit for a request
 */
export async function checkRateLimit(
  req: NextRequest,
  type: RateLimitType = 'api'
): Promise<RateLimitResult> {
  const limiter = rateLimiters[type];
  const clientId = getClientId(req);
  const key = `${type}:${clientId}`;

  try {
    const result = await limiter.consume(key);
    
    return {
      success: true,
      limit: limiter.points,
      remaining: result.remainingPoints,
      resetTime: new Date(Date.now() + result.msBeforeNext),
    };
  } catch (error) {
    if (error instanceof RateLimiterRes) {
      const retryAfter = Math.ceil(error.msBeforeNext / 1000);
      
      return {
        success: false,
        limit: limiter.points,
        remaining: 0,
        resetTime: new Date(Date.now() + error.msBeforeNext),
        retryAfter,
      };
    }
    
    // Unknown error - allow request but log
    console.error('Rate limiter error:', error);
    return {
      success: true,
      limit: limiter.points,
      remaining: limiter.points,
      resetTime: new Date(Date.now() + 60000),
    };
  }
}

/**
 * Create rate limit error response
 */
export function rateLimitResponse(result: RateLimitResult): NextResponse {
  return NextResponse.json(
    {
      error: 'Too Many Requests',
      message: 'Çok fazla istek gönderdiniz. Lütfen bekleyin.',
      retryAfter: result.retryAfter,
      resetTime: result.resetTime.toISOString(),
    },
    {
      status: 429,
      headers: {
        'Retry-After': String(result.retryAfter || 60),
        'X-RateLimit-Limit': String(result.limit),
        'X-RateLimit-Remaining': String(result.remaining),
        'X-RateLimit-Reset': result.resetTime.toISOString(),
      },
    }
  );
}

/**
 * Apply rate limit headers to successful response
 */
export function applyRateLimitHeaders(
  response: NextResponse,
  result: RateLimitResult
): NextResponse {
  response.headers.set('X-RateLimit-Limit', String(result.limit));
  response.headers.set('X-RateLimit-Remaining', String(result.remaining));
  response.headers.set('X-RateLimit-Reset', result.resetTime.toISOString());
  return response;
}

/**
 * Rate limit wrapper for API routes
 * Use this as a middleware wrapper for route handlers
 */
export function withRateLimit(
  type: RateLimitType = 'api'
) {
  return async function rateLimit(
    req: NextRequest,
    handler: () => Promise<NextResponse>
  ): Promise<NextResponse> {
    const result = await checkRateLimit(req, type);
    
    if (!result.success) {
      return rateLimitResponse(result);
    }
    
    const response = await handler();
    return applyRateLimitHeaders(response, result);
  };
}

/**
 * Reset rate limit for a specific client (e.g., after successful login)
 */
export async function resetRateLimit(
  req: NextRequest,
  type: RateLimitType = 'auth'
): Promise<void> {
  const limiter = rateLimiters[type];
  const clientId = getClientId(req);
  const key = `${type}:${clientId}`;
  
  try {
    await limiter.delete(key);
  } catch {
    // Ignore errors on reset
  }
}

/**
 * Get current rate limit status without consuming
 */
export async function getRateLimitStatus(
  req: NextRequest,
  type: RateLimitType = 'api'
): Promise<RateLimitResult> {
  const limiter = rateLimiters[type];
  const clientId = getClientId(req);
  const key = `${type}:${clientId}`;

  try {
    const result = await limiter.get(key);
    
    if (!result) {
      return {
        success: true,
        limit: limiter.points,
        remaining: limiter.points,
        resetTime: new Date(Date.now() + 60000),
      };
    }
    
    return {
      success: result.remainingPoints > 0,
      limit: limiter.points,
      remaining: result.remainingPoints,
      resetTime: new Date(Date.now() + result.msBeforeNext),
      retryAfter: result.remainingPoints <= 0 ? Math.ceil(result.msBeforeNext / 1000) : undefined,
    };
  } catch {
    return {
      success: true,
      limit: limiter.points,
      remaining: limiter.points,
      resetTime: new Date(Date.now() + 60000),
    };
  }
}
