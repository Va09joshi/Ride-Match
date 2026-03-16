const nodemailer = require('nodemailer');
require('dotenv').config();

let transporter;

const getTransporter = () => {
  if (transporter) {
    return transporter;
  }

  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = Number(process.env.SMTP_PORT || 587);
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpService = process.env.SMTP_SERVICE;

  if (!smtpUser || !smtpPass || (!smtpHost && !smtpService)) {
    throw new Error('Email service is not configured. Set SMTP_HOST or SMTP_SERVICE together with SMTP_USER and SMTP_PASS.');
  }

  const transportConfig = smtpService
    ? {
        service: smtpService,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
      }
    : {
        host: smtpHost,
        port: smtpPort,
        secure: smtpPort === 465,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
      };

  transporter = nodemailer.createTransport(transportConfig);
  return transporter;
};

const sendMail = async ({ to, subject, text, html }) => {
  const mailer = getTransporter();
  const from = process.env.MAIL_FROM || process.env.SMTP_USER;

  return mailer.sendMail({
    from,
    to,
    subject,
    text,
    html,
  });
};

module.exports = { sendMail };