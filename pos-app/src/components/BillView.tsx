import React from 'react';
import type { Bill } from '../types';

interface BillViewProps {
  bill: Bill;
  shopName: string;
  onClose: () => void;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function formatDate(isoString: string): string {
  const date = new Date(isoString);
  const d = date.getDate();
  const month = MONTHS[date.getMonth()];
  const year = date.getFullYear();
  let hours = date.getHours();
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'PM' : 'AM';
  hours = hours % 12 || 12;
  return `${d} ${month} ${year}, ${hours}:${minutes} ${ampm}`;
}

function fmt(amount: number): string {
  return `₹${amount.toFixed(2)}`;
}

function buildWhatsAppText(bill: Bill, shopName: string): string {
  const line = '─────────────────────';
  const items = bill.items
    .map((i) => `  • ${i.name} ×${i.quantity} ${i.unit} = ${fmt(i.lineTotal)}`)
    .join('\n');

  const discountLine = bill.discount > 0 ? `\nDiscount: -${fmt(bill.discount)}` : '';

  return (
    `*${shopName}*\n` +
    `Bill No: ${bill.billNumber}\n` +
    `Date: ${formatDate(bill.date)}\n` +
    (bill.customerName ? `Customer: ${bill.customerName}\n` : '') +
    (bill.customerPhone ? `Phone: ${bill.customerPhone}\n` : '') +
    `${line}\n` +
    `${items}\n` +
    `${line}\n` +
    `Subtotal: ${fmt(bill.subtotal)}\n` +
    `CGST: ${fmt(bill.totalCGST)}\n` +
    `SGST: ${fmt(bill.totalSGST)}` +
    `${discountLine}\n` +
    `*Total: ${fmt(bill.grandTotal)}*\n` +
    `Payment: ${bill.paymentMode.toUpperCase()}\n` +
    `${line}\n` +
    `Thank you for shopping! 🙏`
  );
}

const BillView: React.FC<BillViewProps> = ({ bill, shopName, onClose }) => {
  function shareWhatsApp() {
    const text = buildWhatsAppText(bill, shopName);
    const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank');
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal bill-view" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Bill #{bill.billNumber}</h3>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <div className="modal-body">
          <div className="bill-print">
            <p className="shop-name">{shopName}</p>
            <p className="shop-sub">Kerala, India</p>

            <hr className="divider" />

            <div className="meta-row">
              <span><strong>Bill No:</strong> {bill.billNumber}</span>
              <span><strong>Date:</strong> {formatDate(bill.date)}</span>
            </div>
            {(bill.customerName || bill.customerPhone) && (
              <div className="meta-row">
                {bill.customerName && <span><strong>Customer:</strong> {bill.customerName}</span>}
                {bill.customerPhone && <span><strong>Phone:</strong> {bill.customerPhone}</span>}
              </div>
            )}
            <div className="meta-row">
              <span>
                <strong>Payment:</strong>{' '}
                <span className={`pay-chip ${bill.paymentMode}`}>
                  {bill.paymentMode.toUpperCase()}
                </span>
              </span>
            </div>

            <hr className="divider" />

            <table>
              <thead>
                <tr>
                  <th>Item</th>
                  <th className="right">Qty</th>
                  <th className="right">Rate</th>
                  <th className="right">Taxable</th>
                  <th className="right">Total</th>
                </tr>
              </thead>
              <tbody>
                {bill.items.map((item) => (
                  <tr key={item.productId}>
                    <td>{item.name}</td>
                    <td className="right">{item.quantity} {item.unit}</td>
                    <td className="right">{fmt(item.price)}</td>
                    <td className="right">{fmt(item.taxableAmount)}</td>
                    <td className="right">{fmt(item.lineTotal)}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            <hr className="divider" />

            <div className="tax-row"><span>CGST</span><span>{fmt(bill.totalCGST)}</span></div>
            <div className="tax-row"><span>SGST</span><span>{fmt(bill.totalSGST)}</span></div>

            {bill.discount > 0 && (
              <div className="tax-row" style={{ color: 'var(--danger)' }}>
                <span>Discount</span><span>− {fmt(bill.discount)}</span>
              </div>
            )}

            <div className="grand-row">
              <span>Grand Total</span>
              <span>{fmt(bill.grandTotal)}</span>
            </div>

            <p className="footer-note">Thank you for shopping! Come again. 🙏</p>
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Close</button>
          <button
            className="btn"
            style={{ background: '#25D366', color: '#fff' }}
            onClick={shareWhatsApp}
          >
            WhatsApp
          </button>
          <button className="btn btn-primary" onClick={() => window.print()}>
            🖨️ Print
          </button>
        </div>
      </div>
    </div>
  );
};

export default BillView;
