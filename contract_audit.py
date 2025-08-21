#!/usr/bin/env python3
"""
Contract Mapping Audit Script
Investigates where unrealistic contracts came from in the mapping process
"""

import csv

def main():
    print('🔍 CONTRACT MAPPING AUDIT')
    print('=' * 80)
    
    print('🎯 Goal: Find where low-rated players got unrealistic contracts')
    print('=' * 80)
    
    # Read the enhanced CSV to see what contracts players actually have
    print('📊 ANALYZING PLAYER CONTRACTS BY OVERALL RATING:')
    print('=' * 80)
    
    contracts_by_overall = {}
    suspicious_contracts = []
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            overall_str = row.get('overallRating', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            team = row.get('Team', '').strip()
            position = row.get('Position', '').strip()
            first_name = row.get('firstName', '').strip()
            last_name = row.get('lastName', '').strip()
            
            if overall_str and contract_apy_str:
                try:
                    overall = int(overall_str)
                    contract_apy = float(contract_apy_str)
                    
                    # Group by overall rating
                    if overall not in contracts_by_overall:
                        contracts_by_overall[overall] = []
                    
                    contracts_by_overall[overall].append({
                        'team': team,
                        'position': position,
                        'name': f"{first_name} {last_name}",
                        'apy': contract_apy
                    })
                    
                    # Flag suspicious contracts
                    if overall < 70 and contract_apy > 15:  # Low overall, high contract
                        suspicious_contracts.append({
                            'team': team,
                            'position': position,
                            'name': f"{first_name} {last_name}",
                            'overall': overall,
                            'apy': contract_apy,
                            'reason': 'Low overall, very high contract'
                        })
                    elif overall < 75 and contract_apy > 25:  # Medium overall, extremely high contract
                        suspicious_contracts.append({
                            'team': team,
                            'position': position,
                            'name': f"{first_name} {last_name}",
                            'overall': overall,
                            'apy': contract_apy,
                            'reason': 'Medium overall, extremely high contract'
                        })
                    
                except ValueError:
                    continue
    
    # Show contracts by overall rating
    print('📊 CONTRACTS BY OVERALL RATING:')
    print('=' * 80)
    
    for overall in sorted(contracts_by_overall.keys()):
        contracts = contracts_by_overall[overall]
        if contracts:
            avg_apy = sum(c['apy'] for c in contracts) / len(contracts)
            min_apy = min(c['apy'] for c in contracts)
            max_apy = max(c['apy'] for c in contracts)
            
            print(f'Overall {overall:2}: {len(contracts):2} players | APY: ${min_apy:5.2f}M - ${max_apy:5.2f}M | Avg: ${avg_apy:5.2f}M')
            
            # Show any extreme outliers
            for contract in contracts:
                if contract['apy'] > avg_apy * 3:  # 3x average is suspicious
                    print(f'  ⚠️  OUTLIER: {contract["name"]} ({contract["team"]} {contract["position"]}) - ${contract["apy"]:.2f}M')
    
    # Show suspicious contracts
    print(f'\n🚨 SUSPICIOUS CONTRACTS FOUND: {len(suspicious_contracts)}')
    print('=' * 80)
    
    if suspicious_contracts:
        # Sort by most suspicious (lowest overall, highest contract)
        suspicious_contracts.sort(key=lambda x: (x['overall'], -x['apy']))
        
        for contract in suspicious_contracts:
            print(f'{contract["name"]} ({contract["team"]} {contract["position"]})')
            print(f'  Overall: {contract["overall"]} | APY: ${contract["apy"]:.2f}M')
            print(f'  Reason: {contract["reason"]}')
            print()
    else:
        print('✅ No suspicious contracts found!')
    
    # Now let's look at the specific examples from the CPU analysis
    print('🔍 INVESTIGATING SPECIFIC EXAMPLES FROM CPU ANALYSIS:')
    print('=' * 80)
    
    target_players = [
        ('Arizona', 'QB', 62, 31.42),
        ('Atlanta', 'QB', 73, 27.72),
        ('Baltimore', 'QB', 99, 31.63),
        ('Buffalo', 'QB', 99, 33.11)
    ]
    
    for target_team, target_pos, target_overall, target_apy in target_players:
        print(f'\n🔍 Looking for: {target_team} {target_pos} - OVR {target_overall} - ${target_apy}M')
        print('-' * 60)
        
        found = False
        with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            for row in reader:
                team = row.get('Team', '').strip()
                position = row.get('Position', '').strip()
                overall_str = row.get('overallRating', '').strip()
                contract_apy_str = row.get('contractAPY_M', '').strip()
                first_name = row.get('firstName', '').strip()
                last_name = row.get('lastName', '').strip()
                
                if (team == target_team and position == target_pos and 
                    overall_str and contract_apy_str):
                    try:
                        overall = int(overall_str)
                        contract_apy = float(contract_apy_str)
                        
                        if abs(overall - target_overall) <= 2 and abs(contract_apy - target_apy) <= 1:
                            print(f'✅ FOUND: {first_name} {last_name}')
                            print(f'   Team: {team} | Position: {position}')
                            print(f'   Overall: {overall} | APY: ${contract_apy:.2f}M')
                            print(f'   Contract Years: {row.get("contractYears", "N/A")}')
                            print(f'   Total Value: ${row.get("contractTotalValue_M", "N/A")}M')
                            print(f'   Guaranteed: ${row.get("contractTotalGuaranteed_M", "N/A")}M')
                            found = True
                            break
                    except ValueError:
                        continue
        
        if not found:
            print(f'❌ NOT FOUND: No {target_team} {target_pos} with OVR {target_overall} and APY ${target_apy}M')
    
    # Check if there are any QBs with these exact contracts
    print(f'\n🔍 SEARCHING FOR ALL QBs WITH SUSPICIOUS CONTRACTS:')
    print('=' * 80)
    
    qb_contracts = []
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            position = row.get('Position', '').strip()
            if position == 'QB':
                overall_str = row.get('overallRating', '').strip()
                contract_apy_str = row.get('contractAPY_M', '').strip()
                team = row.get('Team', '').strip()
                first_name = row.get('firstName', '').strip()
                last_name = row.get('lastName', '').strip()
                
                if overall_str and contract_apy_str:
                    try:
                        overall = int(overall_str)
                        contract_apy = float(contract_apy_str)
                        
                        qb_contracts.append({
                            'name': f"{first_name} {last_name}",
                            'team': team,
                            'overall': overall,
                            'apy': contract_apy
                        })
                    except ValueError:
                        continue
    
    # Sort QBs by contract value
    qb_contracts.sort(key=lambda x: x['apy'], reverse=True)
    
    print('Top 10 Highest-Paid QBs:')
    for i, qb in enumerate(qb_contracts[:10], 1):
        print(f'{i:2}. {qb["name"]} ({qb["team"]}) - OVR {qb["overall"]:2} - ${qb["apy"]:5.2f}M')
    
    print(f'\nBottom 10 Lowest-Paid QBs:')
    for i, qb in enumerate(qb_contracts[-10:], 1):
        print(f'{i:2}. {qb["name"]} ({qb["team"]}) - OVR {qb["overall"]:2} - ${qb["apy"]:5.2f}M')

if __name__ == "__main__":
    main()


