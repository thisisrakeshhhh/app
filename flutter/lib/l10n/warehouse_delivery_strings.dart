import 'app_language.dart';
import 'language_controller.dart';

class WdStrings {
  final AppLanguage lang;
  const WdStrings(this.lang);

  static WdStrings get current => WdStrings(LanguageController.instance.currentLanguage);

  // Exact anchor terms to maintain test compatibility
  String get godownStock => 'Godown Stock';
  String get stockValuation => 'Stock Valuation';
  String get loadedInVan => 'Loaded in Van';
  String get expiryRadar => 'Expiry Radar';

  String get boxesUnit {
    switch (lang) {
      case AppLanguage.en:
        return 'Boxes';
      case AppLanguage.hinglish:
        return 'Petis';
      case AppLanguage.hi:
        return 'पेटी';
      case AppLanguage.gu:
        return 'પેટી';
    }
  }

  String get operationsHeader {
    switch (lang) {
      case AppLanguage.en:
        return 'Godown Operations';
      case AppLanguage.hinglish:
        return 'Godown Operations & Work';
      case AppLanguage.hi:
        return 'गोदाम के मुख्य कार्य';
      case AppLanguage.gu:
        return 'ગોડાઉનની મુખ્ય કામગીરી';
    }
  }

  String get truckInwardTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Truck Inward';
      case AppLanguage.hinglish:
        return 'Truck Inward (Maal Aaya)';
      case AppLanguage.hi:
        return 'ट्रक आवक (माल प्राप्ति)';
      case AppLanguage.gu:
        return 'ટ્રક આવક (માલ પ્રાપ્તિ)';
    }
  }

  String get truckInwardSubtitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Vehicle intake & multi-unit cart';
      case AppLanguage.hinglish:
        return 'Gadi number & cart me jodein';
      case AppLanguage.hi:
        return 'गाड़ी नंबर और कार्ट में जोड़ें';
      case AppLanguage.gu:
        return 'ગાડી નંબર અને કાર્ટમાં ઉમેરો';
    }
  }

  String get pickPackTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Shop Orders';
      case AppLanguage.hinglish:
        return 'Dukaan Orders (Pick & Pack)';
      case AppLanguage.hi:
        return 'दुकान आर्डर (पिक एवं पैक)';
      case AppLanguage.gu:
        return 'દુકાન ઓર્ડર (પીક અને પેક)';
    }
  }

  String pickPackSubtitle(int ready, int waiting) {
    switch (lang) {
      case AppLanguage.en:
        return '$ready Ready • $waiting Pending';
      case AppLanguage.hinglish:
        return '$ready Taiyar • $waiting Approval Baaki';
      case AppLanguage.hi:
        return '$ready तैयार • $waiting मंज़ूरी बाकी';
      case AppLanguage.gu:
        return '$ready તૈયાર • $waiting મંજૂરી બાકી';
    }
  }

  String get stockListTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Godown Inventory';
      case AppLanguage.hinglish:
        return 'Godown Stock List';
      case AppLanguage.hi:
        return 'गोदाम स्टॉक सूची';
      case AppLanguage.gu:
        return 'ગોડાઉન સ્ટોક યાદી';
    }
  }

  String stockListSubtitle(int count) {
    switch (lang) {
      case AppLanguage.en:
        return '$count Cartons in shelves';
      case AppLanguage.hinglish:
        return '$count Petiyan godown me';
      case AppLanguage.hi:
        return '$count पेटी गोदाम में उपलब्ध';
      case AppLanguage.gu:
        return '$count પેટી ગોડાઉનમાં ઉપલબ્ધ';
    }
  }

  String get movementRegisterTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Movement Register';
      case AppLanguage.hinglish:
        return 'Aavak-Jaavak Register';
      case AppLanguage.hi:
        return 'आवक-जावक रजिस्टर';
      case AppLanguage.gu:
        return 'આવક-જાવક રજીસ્ટર';
    }
  }

  String get movementRegisterSubtitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Inward receipts & van dispatches';
      case AppLanguage.hinglish:
        return 'Kab maal aaya aur kaha gya';
      case AppLanguage.hi:
        return 'कब माल आया और कहाँ गया';
      case AppLanguage.gu:
        return 'ક્યારે માલ આવ્યો અને ક્યાં ગયો';
    }
  }

  String waitingApprovalBanner(int count) {
    switch (lang) {
      case AppLanguage.en:
        return '$count Orders Waiting for Owner Approval';
      case AppLanguage.hinglish:
        return '$count Order Malik ki Manzoori ke Intezar me';
      case AppLanguage.hi:
        return '$count आर्डर मालिक की मंज़ूरी के इंतज़ार में हैं';
      case AppLanguage.gu:
        return '$count ઓર્ડર માલિકની મંજૂરીની રાહ જુએ છે';
    }
  }

  String get waitingApprovalSub {
    switch (lang) {
      case AppLanguage.en:
        return 'Owner must approve before godown can pick & pack';
      case AppLanguage.hinglish:
        return 'Packing shuru karne ke liye malik ka pass hona zaroori hai';
      case AppLanguage.hi:
        return 'पैकिंग शुरू करने से पहले मालिक का पास करना ज़रूरी है';
      case AppLanguage.gu:
        return 'પેકિંગ શરૂ કરતા પહેલા માલિકનું મંજૂર કરવું જરૂરી છે';
    }
  }

  String get checkOrdersBtn {
    switch (lang) {
      case AppLanguage.en:
        return 'Review';
      case AppLanguage.hinglish:
        return 'Check Karein';
      case AppLanguage.hi:
        return 'चेक करें';
      case AppLanguage.gu:
        return 'તપાસો';
    }
  }

  String get recentTrucksTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Recent Truck Arrivals';
      case AppLanguage.hinglish:
        return 'Haal Hi Me Aaye Truck';
      case AppLanguage.hi:
        return 'हाल ही में आए ट्रक';
      case AppLanguage.gu:
        return 'તાજેતરમાં આવેલી ટ્રકો';
    }
  }

  String get recentDispatchTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Recent Dispatches';
      case AppLanguage.hinglish:
        return 'Haal Hi Me Bheja Gya Maal';
      case AppLanguage.hi:
        return 'हाल ही में भेजा गया माल';
      case AppLanguage.gu:
        return 'તાજેતરમાં મોકલેલો માલ';
    }
  }

  String get viewAllBtn {
    switch (lang) {
      case AppLanguage.en:
        return 'View All >';
      case AppLanguage.hinglish:
        return 'Sab Dekhein >';
      case AppLanguage.hi:
        return 'सब देखें >';
      case AppLanguage.gu:
        return 'બધું જુઓ >';
    }
  }

  // Truck Inward View
  String get inwardHeaderTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Truck Stock Intake (GRN)';
      case AppLanguage.hinglish:
        return 'Truck Stock Intake (Mal Jama)';
      case AppLanguage.hi:
        return 'ट्रक माल आवक (गोदाम में जमा)';
      case AppLanguage.gu:
        return 'ટ્રક માલ આવક (ગોડાઉનમાં જમા)';
    }
  }

  String get handoverToDriverTitle {
    switch (lang) {
      case AppLanguage.en:
        return 'Handover to Driver (Delivery)';
      case AppLanguage.hinglish:
        return 'Driver ko Handover (Delivery)';
      case AppLanguage.hi:
        return 'ड्राइवर को हैंडओवर (डिलीवरी)';
      case AppLanguage.gu:
        return 'ડ્રાઈવરને હેન્ડઓવર (ડિલિવરી)';
    }
  }

  String get handoverToDriverBtn {
    switch (lang) {
      case AppLanguage.en:
        return 'Handover to Driver';
      case AppLanguage.hinglish:
        return 'Driver ko Handover Karein';
      case AppLanguage.hi:
        return 'ड्राइवर को सौंपें';
      case AppLanguage.gu:
        return 'ડ્રાઈવરને સોંપો';
    }
  }

  String get truckNumberLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Truck / Vehicle Number *';
      case AppLanguage.hinglish:
        return 'Truck / Gadi Number *';
      case AppLanguage.hi:
        return 'ट्रक / गाड़ी नंबर *';
      case AppLanguage.gu:
        return 'ટ્રક / વાહન નંબર *';
    }
  }

  String get driverNameLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Driver Name';
      case AppLanguage.hinglish:
        return 'Driver ka Naam';
      case AppLanguage.hi:
        return 'ड्राइवर का नाम';
      case AppLanguage.gu:
        return 'ડ્રાઈવરનું નામ';
    }
  }

  String get supplierLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Factory / Plant / Supplier Depot';
      case AppLanguage.hinglish:
        return 'Factory / Plant / Supplier Depot';
      case AppLanguage.hi:
        return 'फ़ैक्ट्री / सप्लायर डिपो';
      case AppLanguage.gu:
        return 'ફેક્ટરી / સપ્લાયર ડેપો';
    }
  }

  String get selectProductLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Select Product / SKU';
      case AppLanguage.hinglish:
        return 'Maal / Product Chunein';
      case AppLanguage.hi:
        return 'उत्पाद / माल चुनें';
      case AppLanguage.gu:
        return 'ઉત્પાદન / માલ પસંદ કરો';
    }
  }

  String get boxUnitLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Boxes (Cartons)';
      case AppLanguage.hinglish:
        return 'Peti (Box)';
      case AppLanguage.hi:
        return 'पेटी (Box)';
      case AppLanguage.gu:
        return 'પેટી (Box)';
    }
  }

  String get stripUnitLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Strips (Ladi)';
      case AppLanguage.hinglish:
        return 'Ladi (Strip)';
      case AppLanguage.hi:
        return 'लड़ी (Strip)';
      case AppLanguage.gu:
        return 'લડી (Strip)';
    }
  }

  String get pieceUnitLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Loose Pieces';
      case AppLanguage.hinglish:
        return 'Khulla (Piece)';
      case AppLanguage.hi:
        return 'खुल्ला पीस';
      case AppLanguage.gu:
        return 'છૂટક પીસ';
    }
  }

  String get addToCartBtn {
    switch (lang) {
      case AppLanguage.en:
        return '+ Add to Intake Cart';
      case AppLanguage.hinglish:
        return '+ Cart Me Jodein';
      case AppLanguage.hi:
        return '+ कार्ट में जोड़ें';
      case AppLanguage.gu:
        return '+ કાર્ટમાં ઉમેરો';
    }
  }

  String get saveToGodownBtn {
    switch (lang) {
      case AppLanguage.en:
        return '✓ Save to Godown Database';
      case AppLanguage.hinglish:
        return '✓ Godown me Maal Jama Karein';
      case AppLanguage.hi:
        return '✓ गोदाम में माल जमा करें';
      case AppLanguage.gu:
        return '✓ ગોડાઉનમાં માલ જમા કરો';
    }
  }

  // Delivery Strings
  String get deliveryAddressLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Delivery Address:';
      case AppLanguage.hinglish:
        return 'Dukaan ka Poora Pata (Delivery Address):';
      case AppLanguage.hi:
        return 'दुकान का पूरा पता (Delivery Address):';
      case AppLanguage.gu:
        return 'દુકાનનું પૂરું સરનામું (Delivery Address):';
    }
  }

  String get shopkeeperLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Shopkeeper:';
      case AppLanguage.hinglish:
        return 'Dukaandar:';
      case AppLanguage.hi:
        return 'दुकानदार:';
      case AppLanguage.gu:
        return 'દુકાનદાર:';
    }
  }

  String get itemsBoxesLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Items (Boxes)';
      case AppLanguage.hinglish:
        return 'Samaan (Boxes)';
      case AppLanguage.hi:
        return 'सामान (Boxes)';
      case AppLanguage.gu:
        return 'સામાન (Boxes)';
    }
  }

  String get codToCollectLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'COD Cash to Collect';
      case AppLanguage.hinglish:
        return 'Cash Lena Hai (COD)';
      case AppLanguage.hi:
        return 'कैश लेना है (COD)';
      case AppLanguage.gu:
        return 'રોકડ લેવાની છે (COD)';
    }
  }

  String get markDeliveredBtn {
    switch (lang) {
      case AppLanguage.en:
        return '✓ Mark Delivered';
      case AppLanguage.hinglish:
        return '✓ Delivery Ho Gayi (Mark Delivered)';
      case AppLanguage.hi:
        return '✓ डिलीवरी हो गई (Mark Delivered)';
      case AppLanguage.gu:
        return '✓ ડિલિવરી થઈ ગઈ (Mark Delivered)';
    }
  }

  String get deliveredBadge {
    switch (lang) {
      case AppLanguage.en:
        return '✅ DELIVERED';
      case AppLanguage.hinglish:
        return '✅ Ho Gayi (DELIVERED)';
      case AppLanguage.hi:
        return '✅ हो गई (DELIVERED)';
      case AppLanguage.gu:
        return '✅ થઈ ગઈ (DELIVERED)';
    }
  }

  String get deliveredConfirmedText {
    switch (lang) {
      case AppLanguage.en:
        return 'Order Delivered Successfully ✓';
      case AppLanguage.hinglish:
        return 'Samaan deliver ho chuka hai (Delivered ✓)';
      case AppLanguage.hi:
        return 'सामान डिलीवर हो चुका है (Delivered ✓)';
      case AppLanguage.gu:
        return 'સામાન ડિલિવર થઈ ગયો છે (Delivered ✓)';
    }
  }

  String get deliveryPendingBadge {
    switch (lang) {
      case AppLanguage.en:
        return '🚚 PENDING';
      case AppLanguage.hinglish:
        return '🚚 Delivery Baaki';
      case AppLanguage.hi:
        return '🚚 डिलीवरी बाकी';
      case AppLanguage.gu:
        return '🚚 ડિલિવરી બાકી';
    }
  }

  String categoryName(String cat) {
    switch (cat) {
      case 'All':
        switch (lang) {
          case AppLanguage.en:
            return 'All Products';
          case AppLanguage.hinglish:
            return 'Sab Products';
          case AppLanguage.hi:
            return 'सभी उत्पाद';
          case AppLanguage.gu:
            return 'તમામ માલ';
        }
      case 'Juices & Cold Drinks':
        switch (lang) {
          case AppLanguage.en:
            return '🧃 Juices & Drinks';
          case AppLanguage.hinglish:
            return '🧃 Juice & Drinks';
          case AppLanguage.hi:
            return '🧃 जूस एवं पेय';
          case AppLanguage.gu:
            return '🧃 જ્યુસ અને પીણાં';
        }
      case 'Traditional Namkeen':
        switch (lang) {
          case AppLanguage.en:
            return '🥨 Namkeen & Sev';
          case AppLanguage.hinglish:
            return '🥨 Namkeen & Sev';
          case AppLanguage.hi:
            return '🥨 पारंपरिक नमकीन';
          case AppLanguage.gu:
            return '🥨 નમકીન અને સેવ';
        }
      case 'Potato Wafers':
        switch (lang) {
          case AppLanguage.en:
            return '🥔 Potato Wafers';
          case AppLanguage.hinglish:
            return '🥔 Aaloo Wafers';
          case AppLanguage.hi:
            return '🥔 आलू वेफर्स';
          case AppLanguage.gu:
            return '🥔 બટાકા વેફર્સ';
        }
      case 'Extruded Snacks & Fryums':
        switch (lang) {
          case AppLanguage.en:
            return '🍿 Fryums & Rings';
          case AppLanguage.hinglish:
            return '🍿 Fryums & Rings';
          case AppLanguage.hi:
            return '🍿 फ्रायम्स व रिंग्स';
          case AppLanguage.gu:
            return '🍿 ફ્રાયમ્સ';
        }
      case 'Biscuits & Bakery':
      case 'Bakery & Confectionery':
        switch (lang) {
          case AppLanguage.en:
            return '🍪 Biscuits & Bakery';
          case AppLanguage.hinglish:
            return '🍪 Biscuits & Bakery';
          case AppLanguage.hi:
            return '🍪 बिस्कुट एवं बेकरी';
          case AppLanguage.gu:
            return '🍪 બિસ્કિટ અને બેકરી';
        }
      default:
        return cat;
    }
  }

  // Loading Dock & Movement Registers
  String get loadingDockTab {
    switch (lang) {
      case AppLanguage.en:
        return '🚛 Van Loading';
      case AppLanguage.hinglish:
        return '🚛 Van me Load';
      case AppLanguage.hi:
        return '🚛 वैन में लोड';
      case AppLanguage.gu:
        return '🚛 વાનમાં લોડ';
    }
  }

  String inwardLogTab(int count) {
    switch (lang) {
      case AppLanguage.en:
        return '🚚 Inward Log ($count)';
      case AppLanguage.hinglish:
        return '🚚 Kab Maal Aaya ($count)';
      case AppLanguage.hi:
        return '🚚 कब माल आया ($count)';
      case AppLanguage.gu:
        return '🚚 ક્યારે માલ આવ્યો ($count)';
    }
  }

  String dispatchLogTab(int count) {
    switch (lang) {
      case AppLanguage.en:
        return '📤 Dispatch Register ($count)';
      case AppLanguage.hinglish:
        return '📤 Kahan Maal Gya ($count)';
      case AppLanguage.hi:
        return '📤 कहाँ माल गया ($count)';
      case AppLanguage.gu:
        return '📤 ક્યાં માલ ગયો ($count)';
    }
  }

  String get loadingAndRegistersHeader {
    switch (lang) {
      case AppLanguage.en:
        return 'Vehicle Loading & Stock Registers';
      case AppLanguage.hinglish:
        return 'Vehicle Loading & Registers (Aavak - Jaavak)';
      case AppLanguage.hi:
        return 'गाड़ी लोडिंग एवं रजिस्टर (आवक - जावक)';
      case AppLanguage.gu:
        return 'વાહન લોડિંગ અને રજિસ્ટર (આવક - જાવક)';
    }
  }

  String get noInwardLogged {
    switch (lang) {
      case AppLanguage.en:
        return 'No stock inward logged yet';
      case AppLanguage.hinglish:
        return 'Koi aavak darj nahi hui hai';
      case AppLanguage.hi:
        return 'कोई आवक दर्ज नहीं हुई है';
      case AppLanguage.gu:
        return 'કોઈ આવક નોંધાયેલ નથી';
    }
  }

  String get addInwardFromTabHint {
    switch (lang) {
      case AppLanguage.en:
        return 'Record new stock arrivals from Truck Inward tab';
      case AppLanguage.hinglish:
        return 'Truck Inward tab se naya maal darj karein';
      case AppLanguage.hi:
        return 'ट्रक आवक टैब से नया माल दर्ज करें';
      case AppLanguage.gu:
        return 'ટ્રક આવક ટેબમાંથી નવો માલ દાખલ કરો';
    }
  }

  String get godownReceivedBadge {
    switch (lang) {
      case AppLanguage.en:
        return 'Godown Stocked ✓';
      case AppLanguage.hinglish:
        return 'Godown me Jama ✓';
      case AppLanguage.hi:
        return 'गोदाम में जमा ✓';
      case AppLanguage.gu:
        return 'ગોડાઉનમાં જમા ✓';
    }
  }

  String get driverLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Driver';
      case AppLanguage.hinglish:
        return 'Driver';
      case AppLanguage.hi:
        return 'चालक';
      case AppLanguage.gu:
        return 'ડ્રાઈવર';
    }
  }

  String get plantSupplierLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Supplier';
      case AppLanguage.hinglish:
        return 'Plant';
      case AppLanguage.hi:
        return 'प्लांट';
      case AppLanguage.gu:
        return 'પ્લાન્ટ';
    }
  }

  String get arrivedAtLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Arrived at';
      case AppLanguage.hinglish:
        return 'Kab Aaya';
      case AppLanguage.hi:
        return 'कब आया';
      case AppLanguage.gu:
        return 'ક્યારે આવ્યો';
    }
  }

  String get itemsInwardHeader {
    switch (lang) {
      case AppLanguage.en:
        return 'Items Received in Stock:';
      case AppLanguage.hinglish:
        return 'Kya Kya Maal Aaya (Items Inward):';
      case AppLanguage.hi:
        return 'क्या क्या माल आया (Items Inward):';
      case AppLanguage.gu:
        return 'કયો કયો માલ આવ્યો (Items Inward):';
    }
  }

  String get totalReceivedLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Total Received:';
      case AppLanguage.hinglish:
        return 'Kul Aavak (Total Received):';
      case AppLanguage.hi:
        return 'कुल आवक (Total Received):';
      case AppLanguage.gu:
        return 'કુલ આવક (Total Received):';
    }
  }

  String get piecesUnit {
    switch (lang) {
      case AppLanguage.en:
        return 'pcs';
      case AppLanguage.hinglish:
        return 'pcs';
      case AppLanguage.hi:
        return 'पीस';
      case AppLanguage.gu:
        return 'પીસ';
    }
  }

  String get stripsUnit {
    switch (lang) {
      case AppLanguage.en:
        return 'strips';
      case AppLanguage.hinglish:
        return 'ladi';
      case AppLanguage.hi:
        return 'लड़ी';
      case AppLanguage.gu:
        return 'લડી';
    }
  }

  String get noDispatchLogged {
    switch (lang) {
      case AppLanguage.en:
        return 'No outward dispatches recorded yet';
      case AppLanguage.hinglish:
        return 'Koi jaavak darj nahi hui hai';
      case AppLanguage.hi:
        return 'कोई जावक दर्ज नहीं हुई है';
      case AppLanguage.gu:
        return 'કોઈ જાવક નોંધાયેલ નથી';
    }
  }

  String get autoDispatchHint {
    switch (lang) {
      case AppLanguage.en:
        return 'Dispatches appear automatically when orders are packed & dispatched';
      case AppLanguage.hinglish:
        return 'Order pack hone par yahan apne aap dikhega';
      case AppLanguage.hi:
        return 'ऑर्डर पैक होने पर यहाँ अपने आप दिखेगा';
      case AppLanguage.gu:
        return 'ઓર્ડર પેક થવા પર અહીં આપોઆપ દેખાશે';
    }
  }

  String get orderLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Order';
      case AppLanguage.hinglish:
        return 'Order';
      case AppLanguage.hi:
        return 'ऑर्डर';
      case AppLanguage.gu:
        return 'ઓર્ડર';
    }
  }

  String get dispatchedAtLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Dispatched at';
      case AppLanguage.hinglish:
        return 'Kab Gya';
      case AppLanguage.hi:
        return 'कब गया';
      case AppLanguage.gu:
        return 'ક્યારે ગયો';
    }
  }

  String get itemsDispatchedHeader {
    switch (lang) {
      case AppLanguage.en:
        return 'Items Dispatched:';
      case AppLanguage.hinglish:
        return 'Kya Kya Samaan Gya:';
      case AppLanguage.hi:
        return 'क्या क्या सामान गया:';
      case AppLanguage.gu:
        return 'કયો સામાન ગયો:';
    }
  }

  String get totalCartonsDispatched {
    switch (lang) {
      case AppLanguage.en:
        return 'Total Boxes Dispatched:';
      case AppLanguage.hinglish:
        return 'Kul Peti Ravana:';
      case AppLanguage.hi:
        return 'कुल पेटी रवाना:';
      case AppLanguage.gu:
        return 'કુલ પેટી રવાના:';
    }
  }

  String get alreadyPaidLabel {
    switch (lang) {
      case AppLanguage.en:
        return 'Prepaid / Cleared';
      case AppLanguage.hinglish:
        return 'Pehle se chukta';
      case AppLanguage.hi:
        return 'पहले से चुकता';
      case AppLanguage.gu:
        return 'અગાઉથી ચૂકવેલ';
    }
  }

  String ownerApprovalStatus(bool approved) {
    if (approved) {
      switch (lang) {
        case AppLanguage.en:
          return '✓ Owner Approved';
        case AppLanguage.hinglish:
          return '✓ Owner Approved (Pass Kar Diya)';
        case AppLanguage.hi:
          return '✓ Owner Approved (मालिक ने पास कर दिया)';
        case AppLanguage.gu:
          return '✓ Owner Approved (માલિકે મંજૂર કર્યું)';
      }
    } else {
      switch (lang) {
        case AppLanguage.en:
          return '⏳ Waiting for Owner Approval';
        case AppLanguage.hinglish:
          return '⏳ Waiting for Owner Approval (Manzoori Baaki)';
        case AppLanguage.hi:
          return '⏳ Waiting for Owner Approval (मालिक की मंज़ूरी बाकी)';
        case AppLanguage.gu:
          return '⏳ Waiting for Owner Approval (માલિકની મંજૂરી બાકી)';
      }
    }
  }

  String ownerApprovalSubtitle(bool approved) {
    if (approved) {
      switch (lang) {
        case AppLanguage.en:
          return 'Ready for packing & van dispatch';
        case AppLanguage.hinglish:
          return 'Packing aur van dispatch ke liye taiyar';
        case AppLanguage.hi:
          return 'पैकिंग और वैन रवानगी के लिए तैयार';
        case AppLanguage.gu:
          return 'પેકિંગ અને વાન ડિસ્પેચ માટે તૈયાર';
      }
    } else {
      switch (lang) {
        case AppLanguage.en:
          return 'Goods will be packed once owner approves';
        case AppLanguage.hinglish:
          return 'Owner ki manzoori ke baad hi pack kiya jayega';
        case AppLanguage.hi:
          return 'मालिक की मंजूरी के बाद ही माल पैक किया जाएगा';
        case AppLanguage.gu:
          return 'માલિકની મંજૂરી પછી જ માલ પેક થશે';
      }
    }
  }
}
