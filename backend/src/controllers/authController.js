'use strict';
const authService = require('../services/authService');
const tokenService = require('../services/tokenService');
const deviceService = require('../services/deviceService');
const auditService = require('../services/auditService');
const users = require('../services/userService');

/** Envoltorio: centraliza try/catch de los handlers async. */
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const ok = (res, data, status = 200) => res.status(status).json({ success: true, data });

module.exports = {
  register: wrap(async (req, res) => ok(res, await authService.register(req.body, req), 201)),

  login: wrap(async (req, res) => ok(res, await authService.login(req.body, req))),

  verifyOtp: wrap(async (req, res) => ok(res, await authService.verifyOtp(req.body, req))),

  resendOtp: wrap(async (req, res) => ok(res, await authService.resendOtp(req.body, req))),

  forgotPassword: wrap(async (req, res) => ok(res, await authService.forgotPassword(req.body, req))),

  resetPassword: wrap(async (req, res) => ok(res, await authService.resetPassword(req.body, req))),

  changePassword: wrap(async (req, res) =>
    ok(res, await authService.changePassword({ userId: req.userId, ...req.body }, req))),

  setPin: wrap(async (req, res) =>
    ok(res, await authService.setPin({ userId: req.userId, pin: req.body.pin }, req))),

  verifyPin: wrap(async (req, res) =>
    ok(res, await authService.verifyPin({ userId: req.userId, pin: req.body.pin }, req))),

  enrollBiometric: wrap(async (req, res) =>
    ok(res, await authService.enrollBiometric({ userId: req.userId, ...req.body }, req))),

  disableBiometric: wrap(async (req, res) => {
    await deviceService.disableBiometric(req.userId, req.body.deviceId);
    return ok(res, { message: 'Biometría desactivada en este dispositivo.' });
  }),

  biometricLogin: wrap(async (req, res) => ok(res, await authService.biometricLogin(req.body, req))),

  refresh: wrap(async (req, res) => ok(res, await authService.refresh(req.body, req))),

  logout: wrap(async (req, res) =>
    ok(res, await authService.logout({ ...req.body, userId: req.userId }, req))),

  me: wrap(async (req, res) => ok(res, {
    user: users.toPublic(req.user),
    nextStep: users.nextStep(req.user),
    devices: await deviceService.listByUser(req.userId),
  })),

  sessions: wrap(async (req, res) => ok(res, {
    sessions: await tokenService.activeSessions(req.userId),
    recentActivity: await auditService.listByUser(req.userId, 15),
  })),
};
