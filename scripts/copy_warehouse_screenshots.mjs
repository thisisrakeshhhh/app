import fs from 'node:fs';
import path from 'node:path';

const src = 'C:\\Users\\Rakesh kumar\\.gemini\\antigravity\\brain\\46902927-9b4b-448f-8786-78ae4ed183dd';
const dest = path.join(process.cwd(), 'docs', 'screenshots', 'warehouse');

if (!fs.existsSync(dest)) {
  fs.mkdirSync(dest, { recursive: true });
}

const files = [
  ['qa_wh_01_home.png', '01_godown_desk_home.png'],
  ['qa_wh_02_stock.png', '02_godown_stock_inventory.png'],
  ['qa_wh_03_product_detail.png', '03_product_detail_sheet.png'],
  ['qa_wh_scanner_active.png', '04_camera_barcode_scanner.png'],
  ['qa_wh_picking.png', '05_picking_queue_empty.png'],
  ['qa_wh_picking_with_order.png', '06_picking_and_carton_packing.png'],
  ['qa_wh_dispatch.png', '07_dispatch_batch_handover.png'],
  ['qa_wh_returns_updated.png', '08_returns_rma_desk.png'],
  ['qa_wh_return_inspect.png', '09_driver_return_inspect_dialog.png'],
  ['qa_wh_09_rma_inspection.png', '10_customer_rma_inspect_dialog.png']
];

for (const [s, d] of files) {
  const sPath = path.join(src, s);
  const dPath = path.join(dest, d);
  if (fs.existsSync(sPath)) {
    fs.copyFileSync(sPath, dPath);
    console.log(`Copied ${s} -> ${d} (${fs.statSync(dPath).size} bytes)`);
  } else {
    console.error(`Source not found: ${sPath}`);
  }
}
