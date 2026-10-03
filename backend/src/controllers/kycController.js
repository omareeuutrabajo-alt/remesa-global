'use strict';
const kycService = require('../services/kycService');

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const ok = (res, data, status = 200) => res.status(status).json({ success: true, data });

module.exports = {
  submit: wrap(async (req, res) => ok(res, await kycService.submit({
    userId: req.userId,
    ...req.body,
    files: req.files,
  }, req), 201)),

  status: wrap(async (req, res) => ok(res, await kycService.status(req.userId))),

  limits: wrap(async (req, res) => ok(res, kycService.limitsFor(req.user.kyc_level))),

  /** Solo desarrollo: simula la respuesta del proveedor de verificación. */
  review: wrap(async (req, res) => {
    const submission = await kycService.latest(req.userId);
    return ok(res, await kycService.review({
      submissionId: submission?.id,
      approved: req.body.approved !== false,
      reason: req.body.reason ?? 'Documento ilegible',
    }));
  }),
};
