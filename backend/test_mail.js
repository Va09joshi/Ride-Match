require('dotenv').config({path: './.env'});
const { sendMail } = require('./config/mailer');

async function test() {
  try {
    console.log("Sending test email...");
    const result = await sendMail({
      to: process.env.SMTP_USER,
      subject: "Test email from ridematch",
      text: "This is a test email.",
      html: "<p>This is a test email.</p>"
    });
    console.log("Success:", result);
  } catch (err) {
    console.error("Error sending mail:", err);
  }
}
test();
