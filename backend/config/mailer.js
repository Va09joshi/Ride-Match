const nodemailer = require('nodemailer');
const dns = require('dns');
require('dotenv').config();

let transporter;

const getTransporter = () => {
  if (transporter) {
    return transporter;
  }

  if (typeof dns.setDefaultResultOrder === 'function') {
    // Prefer IPv4 records first to avoid IPv6 unreachable errors on some hosts.
    dns.setDefaultResultOrder('ipv4first');
  }

  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = Number(process.env.SMTP_PORT || 587);
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpService = process.env.SMTP_SERVICE;
  const normalizedService = smtpService?.trim().toLowerCase();
  const resolvedHost = smtpHost || (normalizedService === 'gmail' ? 'smtp.gmail.com' : null);

  if (!smtpUser || !smtpPass || !resolvedHost) {
    throw new Error('Email service is not configured. Set SMTP_HOST or SMTP_SERVICE together with SMTP_USER and SMTP_PASS.');
  }

  const transportConfig = {
    host: resolvedHost,
    port: smtpPort,
    secure: smtpPort === 465,
    requireTLS: smtpPort !== 465,
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000,
    lookup: (hostname, options, callback) => {
      dns.lookup(hostname, { family: 4, all: false }, callback);
    },
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
    tls: {
      servername: resolvedHost,
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