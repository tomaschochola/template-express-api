/**
 * @file
 * @author Tomáš Chochola <tomaschochola@tomaschochola.cz>
 * @copyright © 2026 Tomáš Chochola <tomaschochola@tomaschochola.cz>
 *
 * @license CC-BY-ND-4.0
 *
 * @see {@link https://creativecommons.org/licenses/by-nd/4.0/} License
 * @see {@link https://github.com/tomaschochola} GitHub Profile
 * @see {@link https://github.com/sponsors/tomaschochola} GitHub Sponsors
 */

import './observability.js';

import { STATUS_CODES } from 'node:http';

import { logs, SeverityNumber } from '@opentelemetry/api-logs';
import {
  ATTR_ERROR_TYPE,
  ATTR_EXCEPTION_MESSAGE,
  ATTR_EXCEPTION_STACKTRACE,
  ATTR_EXCEPTION_TYPE,
  ATTR_HTTP_RESPONSE_STATUS_CODE,
} from '@opentelemetry/semantic-conventions';
import compress from 'compression';
import cookieParser from 'cookie-parser';
import type { ErrorRequestHandler, Express, RequestHandler } from 'express';
import express from 'express';
import createHttpError from 'http-errors';

const port = Number(process.env['PORT'] ?? '61400');

if (!Number.isInteger(port) || port < 1 || port > 65_535) {
  throw new RangeError('PORT must be an integer between 1 and 65535.');
}

const logger = logs.getLogger('@tomaschochola/template-express-api');
const app: Express = express();

app.disable('x-powered-by');

app.set('views', './views');
app.set('view engine', 'ejs');

app.use(compress());
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const setSecurityHeaders: RequestHandler = (_req, res, next) => {
  if (res.headersSent) {
    next();

    return;
  }

  res.setHeader('Strict-Transport-Security', 'max-age=63072000; includeSubDomains; preload');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader(
    'Content-Security-Policy',
    'default-src \'self\'; form-action \'self\'; base-uri \'self\'; object-src \'none\'; style-src \'self\'; font-src \'self\'; frame-ancestors \'none\'; upgrade-insecure-requests',
  );
  res.setHeader('X-DNS-Prefetch-Control', 'off');
  res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  res.setHeader(
    'Permissions-Policy',
    'accelerometer=(), autoplay=(), camera=(), cross-origin-isolated=(), display-capture=(), encrypted-media=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=(), gamepad=(), hid=(), idle-detection=(), serial=(), unload=()',
  );

  next();
};

app.use(setSecurityHeaders);

const setCacheControl: RequestHandler = (_req, res, next) => {
  if (res.headersSent) {
    next();

    return;
  }

  res.setHeader('Cache-Control', 'private, no-store, max-age=0');

  next();
};

app.use(setCacheControl);

const handleOpenapi: RequestHandler = (_req, res) => {
  res.setHeader(
    'Content-Security-Policy',
    'default-src \'none\'; base-uri \'none\'; form-action \'none\'; frame-ancestors \'none\'; script-src https://cdn.jsdelivr.net; style-src \'self\' \'unsafe-inline\'; img-src \'self\' data: blob: https:; font-src data:; connect-src \'self\'; worker-src blob:',
  );

  res.render('openapi.ejs', { url: '/static/openapi.json' });
};

app.get('/api/v1/spec', handleOpenapi);

app.use('/static', express.static('static'));

const handleHealthzLive: RequestHandler = (_req, res) => {
  res.status(200).send();
};

app.get('/healthz/live', handleHealthzLive);

const handleNotFound: RequestHandler = (_req, res, next) => {
  if (res.headersSent) {
    next();

    return;
  }

  res.status(404).json({
    errors: [
      {
        status: '404',
        code: '0',
        title: 'Not Found',
      },
    ],
  });
};

app.use(handleNotFound);

const handleError: ErrorRequestHandler = (err, _req, res, next) => {
  const statusCode: number = createHttpError.isHttpError(err) ? err.statusCode : 500;
  const title: string = STATUS_CODES[statusCode] ?? 'Error';
  const errorType: string = err instanceof Error ? err.name : typeof err;
  const message: string = err instanceof Error ? err.message : typeof err === 'string' ? err : 'Unknown error';
  const severityNumber: SeverityNumber = statusCode < 500 ? SeverityNumber.WARN : SeverityNumber.ERROR;
  const severityText: 'ERROR' | 'WARN' = statusCode < 500 ? 'WARN' : 'ERROR';

  logger.emit({
    attributes: {
      [ATTR_ERROR_TYPE]: errorType,
      [ATTR_HTTP_RESPONSE_STATUS_CODE]: statusCode,
      ...(err instanceof Error
        ? {
            [ATTR_EXCEPTION_TYPE]: err.name,
            [ATTR_EXCEPTION_MESSAGE]: err.message,
            ...(err.stack === undefined ? {} : { [ATTR_EXCEPTION_STACKTRACE]: err.stack }),
          }
        : {}),
    },
    severityNumber,
    severityText,
    body: message,
  });

  if (res.headersSent) {
    next(err);

    return;
  }

  res.status(statusCode).json({
    errors: [
      {
        status: String(statusCode),
        code: '0',
        title,
      },
    ],
  });
};

app.use(handleError);

app.listen(port, () => {
  logger.emit({
    body: `Server listening on port ${String(port)} on all network interfaces.`,
    severityNumber: SeverityNumber.INFO,
    severityText: 'INFO',
  });
});
