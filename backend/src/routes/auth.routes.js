'use strict';
const router = require('express').Router();
const c = require('../controllers/authController');
const s = require('../controllers/schemas');
const validate = require('../middleware/validate');
const limit = require('../middleware/rateLimiter');
const { requireAuth } = require('../middleware/auth');

/* ── Públicas ───────────────────────────────────────────── */
router.post('/register',         limit.register, validate(s.register),       c.register);
router.post('/login',            limit.login,    validate(s.login),          c.login);
router.post('/otp/verify',       limit.otp,      validate(s.verifyOtp),      c.verifyOtp);
router.post('/otp/resend',       limit.otp,      validate(s.resendOtp),      c.resendOtp);
router.post('/password/forgot',  limit.sensitive, validate(s.forgotPassword), c.forgotPassword);
router.post('/password/reset',   limit.sensitive, validate(s.resetPassword),  c.resetPassword);
router.post('/biometric/login',  limit.login,    validate(s.biometricLogin), c.biometricLogin);
router.post('/refresh',                          validate(s.refresh),        c.refresh);

/* ── Protegidas ─────────────────────────────────────────── */
router.get ('/me',                      requireAuth, c.me);
router.get ('/sessions',                requireAuth, c.sessions);
router.post('/logout',                  requireAuth, validate(s.logout),          c.logout);
router.post('/pin',                     requireAuth, validate(s.setPin),          c.setPin);
router.post('/pin/verify',              requireAuth, validate(s.verifyPin),       c.verifyPin);
router.post('/password/change',         requireAuth, validate(s.changePassword),  c.changePassword);
router.post('/biometric/enroll',        requireAuth, validate(s.biometricEnroll), c.enrollBiometric);
router.post('/biometric/disable',       requireAuth, validate(s.biometricEnroll), c.disableBiometric);

module.exports = router;
