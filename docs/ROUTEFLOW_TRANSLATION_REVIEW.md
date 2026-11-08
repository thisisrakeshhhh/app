# ROUTEFLOW TRANSLATION REVIEW AUDIT (SLICES S1)

> **Status:** Pending Native Speaker Verification (`reviewed: false`)  
> **Notice:** Every Indic string (Hindi Devanagari and Gujarati script) in this dictionary is marked `reviewed: false`. A native Hindi / Gujarati speaker must review and approve each translation before production release.

---

## 1. Core Trade Glossary (Mandatory FMCG Invariants)

| Key | English | Hinglish | Hindi (`reviewed: false`) | Gujarati (`reviewed: false`) | Context / Operational Meaning |
|---|---|---|---|---|---|
| `today` | Today | Aaj | आज | આજ | Daily beat execution tab & header |
| `shop` | Shop | Dukaan | दुकान | દુકાન | Retailer / Kirana store entity |
| `order` | Order | Order | ऑर्डर | ઓર્ડર | Sales order booking transaction |
| `box` | Box | Peti | पेटी | પેટી | Secondary packaging unit (master carton) |
| `piece` | Piece | Nag | नग | નંગ | Primary individual sales item |
| `strip` | Strip | Strip | स्ट्रिप | સ્ટ્રિપ | Intermediate packaging unit (blister/pouch) |
| `stock` | Stock | Maal | माल | માલ | Available godown / van inventory |
| `due` | Due | Baaki | बाकी | બાકી | Pending ledger receivables |
| `credit` | Credit | Udhaar | उधार | ઉધાર | Khata credit balance / trade credit |
| `account` | Account | Hisaab | हिसाब | હિસાબ | Khata ledger & running balance |
| `collection` | Collection | Vasooli | वसूली | ઉઘરાણી | Payment collection (Cash/UPI/Cheque) |
| `cash` | Cash | Nakad | नकद | રોકડા | Physical currency collection |
| `cheque` | Cheque | Cheque | चेक | ચેક | Bank draft / post-dated cheque |
| `scheme` | Scheme | Scheme | स्कीम | સ્કીમ | Promotional trade discount / offer |
| `discount` | Discount | Chhoot | छूट | છૂટ | Invoice bill-level price reduction |
| `route` | Route | Route | रूट | રૂટ | Beat path sequence (A -> B -> C -> D) |
| `saved_on_phone` | Saved on this phone | Phone me save hua | फ़ोन में सेव हुआ | ફોનમાં સેવ થયું | Offline outbox mutation honesty banner |

---

## 2. Navigation, Actions & Common Controls

| Key | English | Hinglish | Hindi (`reviewed: false`) | Gujarati (`reviewed: false`) |
|---|---|---|---|---|
| `save` | Save | Save karein | सुरक्षित करें | સાચવો |
| `cancel` | Cancel | Cancel | रद्द करें | રદ કરો |
| `close` | Close | Band karein | बंद करें | બંધ કરો |
| `retry` | Retry | Dobara koshish karein | पुनः प्रयास करें | ફરી પ્રયાસ કરો |
| `continue_label` | Continue | Aage badhein | आगे बढ़ें | આગળ વધો |
| `all` | All | Sabhi | सभी | બધા |
| `pending` | Pending | Baaki | बाकी | બાકી |
| `visited` | Visited | Visit kiya | दौरा पूर्ण | મુલાકાત પૂર્ણ |
| `active_visit` | Active Visit | Chalu visit | चालू दौरा | ચાલુ મુલાકાત |
| `route_sketch` | Route sketch (not to scale) | Route sketch (scale par nahi) | रूट स्केच (माप पर नहीं) | રૂટ સ્કેચ (માપ પર નહીં) |
| `search_shops` | Search shops or area... | Dukaan ya area khojein... | दुकान या क्षेत्र खोजें... | દુકાન અથવા વિસ્તાર શોધો... |
| `shops` | Shops | Dukaanein | दुकानें | દુકાનો |
| `cart` | Cart | Cart | कार्ट | કાર્ટ |
| `earn` | Earn | Kamai | कमाई | કમાણી |
| `more` | More | Aur | और | વધુ |
| `language` | Language | Bhasha | भाषा | ભાષા |
| `choose_language` | Choose Language | Bhasha chunein | भाषा चुनें | ભાષા પસંદ કરો |
| `choose_language_subtitle` | Choose your preferred language for the app | App ke liye apni pasandida bhasha chunein | ऐप के लिए अपनी पसंदीदा भाषा चुनें | ઍપ માટે તમારી પસંદગીની ભાષા પસંદ કરો |

---

## 3. Honest Storage & User Wording

| Key | English | Hinglish | Hindi (`reviewed: false`) | Gujarati (`reviewed: false`) |
|---|---|---|---|---|
| `extra_visit_added` | Added {name} for today only, not on permanent route. | {name} aaj ke liye add kiya, kal nahi rahega. | {name} आज के लिए जोड़ा, कल नहीं रहेगा। | {name} આજના દિવસ માટે ઉમેર્યું, કાલે નહીં રહે. |
| `extra_visit_removed` | Removed {name} from today extra visits. | {name} ko aaj ke extra visit se hataya. | {name} को आज के अतिरिक्त दौरे से हटाया। | {name} ને આજના વધારાના મુલાકાતમાંથી હટાવ્યું. |
| `location_not_added` | Location not added | Location nahi jodi gayi | लोकेशन नहीं जोड़ी गई | લોકેશન ઉમેરેલ નથી |
| `add_location` | Add location | Location jodo | लोकेशन जोड़ें | લોકેશન ઉમેરો |
| `address_not_added` | Address not added | Pata nahi joda gaya | पता नहीं जोड़ा गया | સરનામું ઉમેરેલ નથી |
| `add_address` | Add address | Pata jodo | पता जोड़ें | સરનામું ઉમેરો |
| `target_not_set` | Target not set by owner | Owner ne target set nahi kiya | मालिक द्वारा लक्ष्य तय नहीं किया गया | માલિક દ્વારા ટાર્ગેટ સેટ નથી થયો |
| `estimated_earnings_note` | Estimated earnings from orders booked on this phone. Final calculation by owner. | Is phone par book hue orders se andazan kamai. Final hisaab owner karenge. | इस फ़ोन पर बुक हुए ऑर्डर से अनुमानित कमाई। अंतिम हिसाब मालिक करेंगे। | આ ફોન પર બુક થયેલ ઓર્ડર પરથી અંદાજિત કમાણી. છેલ્લો હિસાબ માલિક કરશે. |
| `request_saved_phone` | Request saved on this phone | Request phone me save hui | अनुरोध फ़ोन में सेव हुआ | વિનંતી ફોનમાં સેવ થઈ |
| `not_verified` | Not verified | Verify nahi hua | सत्यापित नहीं | ચકાસાયેલ નથી |
| `ask_owner` | Ask Owner | Owner se puchho | मालिक से पूछें | માલિકને પૂછો |
| `look_good` | Looks good | Sahi hai | सही है | બરાબર છે |
| `change_order` | Change | Badlo | बदलें | બદલો |

---

## 4. Retailer Registration & Outbox Sync

| Key | English | Hinglish | Hindi (`reviewed: false`) | Gujarati (`reviewed: false`) |
|---|---|---|---|---|
| `add_shop_title` | Add New Shop | Nayi dukaan jodo | नई दुकान जोड़ें | નવી દુકાન ઉમેરો |
| `quick_add_subtitle` | Quick-Add Shop (under 20s) | Jaldi dukaan jodo (20 second) | तुरंत दुकान जोड़ें (20 सेकंड) | ઝડપી દુકાન ઉમેરો (20 સેકન્ડ) |
| `shop_name_label` | Shop Name | Dukaan ka naam | दुकान का नाम | દુકાનનું નામ |
| `owner_name_label` | Owner Name | Maalik ka naam | मालिक का नाम | માલિકનું નામ |
| `mobile_label` | Mobile Number (10 digits) | Mobile number (10 ank) | मोबाइल नंबर (10 अंक) | મોબાઇલ નંબર (10 અંક) |
| `route_label` | Beat / Route | Beat / Route | बीट / रूट | બીટ / રૂટ |
| `capture_gps_button` | 📍 Capture Current Location | 📍 GPS location capture karein | 📍 जीपीएस लोकेशन लें | 📍 જીપીએસ લોકેશન લો |
| `save_shop_button` | Save Shop | Dukaan save karein | दुकान सुरक्षित करें | દુકાન સાચવો |
| `class_new` | New | Nayi | नई दुकान | નવી દુકાન |
| `class_a` | Class A | Class A | श्रेणी A | શ્રેણી A |
| `class_b` | Class B | Class B | श्रेणी B | શ્રેણી B |
| `class_c` | Class C | Class C | श्रेणी C | શ્રેણી C |
| `class_d` | Class D (Cash Only) | Class D (Sirf Nakad) | श्रेणी D (केवल नकद) | શ્રેણી D (ફક્ત રોકડા) |
| `waiting_to_sync` | Waiting to sync | Sync ki pratiksha me | सिंक की प्रतीक्षा में | સિંક કરવાની રાહમાં |
| `local_only_mode` | Local Outbox Mode | Local outbox mode | लोकल आउटबॉक्स मोड | લોકલ આઉટબોક્સ મોડ |
| `sync_status_title` | Sync Status | Sync status | सिंक स्थिति | સિંક સ્થિતિ |
| `uploading_to_cloud` | Uploading to Cloud... | Cloud par upload ho raha hai... | क्लाउड पर अपलोड हो रहा है... | ક્લાઉડ પર અપલોડ થઈ રહ્યું છે... |
| `synced_to_cloud` | Synced to Cloud | Cloud par sync ho gaya | क्लाउड पर सिंक हो गया | ક્લાઉડ પર સિંક થઈ ગયું |
| `sync_worker_note` | Sync worker inactive — mutations remain safe on phone. | Sync worker band hai — saare badlav phone me surakshit hain. | सिंक वर्कर अभी निष्क्रिय है — सभी बदलाव फ़ोन पर पूरी तरह सुरक्षित हैं। | સિંક વર્કર બંધ છે — ફેરફારો ફોનમાં સુરક્ષિત છે. |
| `no_orders_beat_prompt` | Select a retailer from your beat and book orders. | Apne beat se dukaan chunein aur order book karein. | अपनी बीट से दुकान चुनें और ऑर्डर बुक करें। | તમારી બીટમાંથી દુકાન પસંદ કરો અને ઓર્ડર બુક કરો. |
| `no_orders_booked_today` | No Orders Booked Yet Today | Aaj abhi tak koi order nahi hua | आज अभी तक कोई ऑर्डर दर्ज नहीं हुआ | આજે હજુ સુધી કોઈ ઓર્ડર નોંધાયેલ નથી |
| `book_first_order` | Book First Order | Pehla order book karein | पहला ऑर्डर बुक करें | પહેલો ઓર્ડર બુક કરો |
| `product_name_example` | Product Name (e.g. Masala Sev) | Product ka naam (jaise Masala Sev) | उत्पाद का नाम (उदा. मसाला सेव) | પ્રોડક્ટનું નામ (દા.ત. મસાલા સેવ) |
| `product_local_name_example` | Hindi / Local Name (e.g. ग्रीन चटनी) | Hindi / Local naam (jaise ग्रीन चटनी) | हिंदी / स्थानीय नाम (उदा. ग्रीन चटनी) | હિન્દી / સ્થાનિક નામ (દા.ત. ગ્રીન ચટણી) |
| `search_products_hint` | Search products, namkeen, wafers... | Products, namkeen, wafers khojein... | उत्पाद, नमकीन, वेफर्स खोजें... | પ્રોડક્ટ્સ, નમકીન, વેફર્સ શોધો... |
